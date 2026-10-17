import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../media/cover_art.dart';
import '../media/group.dart';
import '../media/media_backend.dart' as media;
import '../media/media_backend.dart' show AudioPermissionState, DeleteResult;
import '../media/overrides.dart';
import '../media/track.dart';
import '../player/engine.dart';
import '../player/play_counts.dart';
import '../storage/library_cache.dart';

enum LibraryStatus { idle, checking, needsPermission, scanning, ready, error }

/// How long a cached library is trusted without rescanning. Changes made while the app is open
/// arrive via the media-store listener, so this only bounds changes made while it was closed.
const _cacheTtl = Duration(hours: 6);

/// Media-store events arrive in bursts during a bulk copy; collapse them into one rescan.
const _changeDebounce = Duration(seconds: 2);

/// The on-device library: permission, scanning, caching, favourites, local edits and deletes.
class LibraryController extends ChangeNotifier {
  LibraryController({PlayerEngine? engine}) : _engine = engine ?? PlayerEngine.instance {
    unawaited(_startup());
  }

  final PlayerEngine _engine;

  LibraryStatus status = LibraryStatus.idle;
  AudioPermissionState permission = AudioPermissionState.undetermined;

  /// Live count while a scan is in flight.
  int scanCount = 0;
  String? error;
  Set<String> favorites = {};

  List<Track> _rawTracks = const [];
  TrackOverrides _overrides = {};

  /// Prevents overlapping scans when the user taps "rescan" repeatedly.
  bool _scanning = false;
  bool _disposed = false;

  void Function()? _unsubscribeChanges;
  Timer? _changeTimer;

  // Derived views, cached against the inputs they come from.
  List<Track>? _tracks;
  List<TrackGroup>? _albums;
  List<TrackGroup>? _artists;

  /// The library as the user sees it.
  ///
  /// Every consumer — lists, groupings, search, the player — reads this rather than the raw scan,
  /// so an edit reaches all of them at once, and no scan path has to remember to re-apply
  /// overrides. That is the whole reason this is derived rather than merged into state.
  List<Track> get tracks => _tracks ??= applyOverrides(_rawTracks, _overrides);
  List<TrackGroup> get albums => _albums ??= groupByAlbum(tracks);
  List<TrackGroup> get artists => _artists ??= groupByArtist(tracks);

  /// Whether this track currently has local edits.
  bool hasOverride(String trackId) => _overrides.containsKey(trackId);

  void _update(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  void _setRawTracks(List<Track> tracks) {
    _rawTracks = tracks;
    _invalidateDerived();
  }

  void _invalidateDerived() {
    _tracks = null;
    _albums = null;
    _artists = null;
  }

  Future<void> rescan() async {
    if (_scanning) return;
    _scanning = true;
    // Files may have gained or lost embedded covers since they were last read.
    CoverArt.clear();

    _update(() {
      status = LibraryStatus.scanning;
      scanCount = 0;
      error = null;
    });

    try {
      media.clearResolvedUris();
      final found = await media.scanAudioLibrary(
        onProgress: (count) => _update(() => scanCount = count),
      );

      _update(() {
        _setRawTracks(found);
        status = LibraryStatus.ready;
      });
      // The cache stores scan output, never the overridden view: overrides are re-applied on
      // read, so a later correction to filename parsing is not permanently masked by a stale copy.
      await writeCachedLibrary(found, DateTime.now().millisecondsSinceEpoch);
      await _engine.restorePlayback(tracks);
    } catch (_) {
      // Deliberately generic: media-store errors can embed file paths we do not want surfaced.
      _update(() {
        error = 'Could not read the music on this device.';
        status = LibraryStatus.error;
      });
    } finally {
      _scanning = false;
    }
  }

  Future<void> requestPermission() async {
    try {
      final next = await media.requestAudioPermission();
      _update(() => permission = next);
      _watchForChanges();

      if (next == AudioPermissionState.granted) {
        await rescan();
      } else {
        _update(() => status = LibraryStatus.needsPermission);
      }
    } catch (_) {
      _update(() {
        error = 'Could not request access to your music.';
        status = LibraryStatus.error;
      });
    }
  }

  /// Startup: paint from cache, then refresh from the media store.
  Future<void> _startup() async {
    _update(() => status = LibraryStatus.checking);

    final (cached, savedFavorites, savedOverrides, _) = await (
      readCachedLibrary(),
      readCachedFavorites(),
      readTrackOverrides(),
      // Needed before the library screen can offer "sort by play count".
      PlayCounts.instance.load(),
    ).wait;
    if (_disposed) return;

    final cachedTracks = cached?.tracks ?? const <Track>[];
    final cacheIsFresh =
        cached != null &&
        DateTime.now().millisecondsSinceEpoch - cached.scannedAt < _cacheTtl.inMilliseconds;

    // Show the cached library immediately so a cold start is not a blank screen.
    _update(() {
      favorites = savedFavorites.toSet();
      _overrides = savedOverrides;
      _setRawTracks(cachedTracks);
      if (cachedTracks.isNotEmpty) status = LibraryStatus.ready;
    });

    if (!media.isMediaSupported) {
      _update(() {
        error = 'This device has no music library Muso can read. Run the app on Android.';
        status = LibraryStatus.error;
      });
      return;
    }

    try {
      await _engine.initAudioSession();

      final current = await media.getAudioPermission();
      if (_disposed) return;
      _update(() => permission = current);

      if (current != AudioPermissionState.granted) {
        _update(() => status = LibraryStatus.needsPermission);
        return;
      }

      _watchForChanges();

      if (cacheIsFresh && cachedTracks.isNotEmpty) {
        // Skip the launch rescan entirely: the media-store listener picks up any real change, and
        // Settings still offers a manual rescan.
        await _engine.restorePlayback(tracks);
        return;
      }

      await rescan();
    } catch (_) {
      if (_disposed) return;

      // Anything thrown here is a platform-layer failure: surface it as a state, never as an
      // unhandled exception.
      _update(() {
        error = 'Could not start audio playback on this device.';
        status = LibraryStatus.error;
      });
    }
  }

  /// Rescans when the device's audio actually changes, instead of on every launch.
  void _watchForChanges() {
    if (permission != AudioPermissionState.granted || _unsubscribeChanges != null) return;

    _unsubscribeChanges = () {};
    unawaited(
      media
          .subscribeToMediaChanges(() {
            _changeTimer?.cancel();
            _changeTimer = Timer(_changeDebounce, () => unawaited(rescan()));
          })
          .then((unsubscribe) {
            if (_disposed) {
              unsubscribe();
            } else {
              _unsubscribeChanges = unsubscribe;
            }
          }),
    );
  }

  void toggleFavorite(String trackId) {
    _update(() {
      final next = {...favorites};
      if (!next.remove(trackId)) next.add(trackId);
      favorites = next;
    });
    unawaited(writeCachedFavorites(favorites));
  }

  Future<void> _persistOverrides(TrackOverrides next) async {
    _update(() {
      _overrides = next;
      _invalidateDerived();
    });
    await writeTrackOverrides(next);
  }

  /// Replaces filename-derived metadata locally. The audio file is never touched.
  Future<void> editTrack(String trackId, TrackOverride patch) async {
    final scanned = _rawTracks.where((track) => track.id == trackId).firstOrNull;
    if (scanned == null) return;

    final merged = mergeOverride(scanned, _overrides[trackId], patch);
    final next = {..._overrides};

    if (merged != null) {
      next[trackId] = merged;
    } else {
      next.remove(trackId);
    }

    await _persistOverrides(next);
  }

  /// Drops a track's local edits, restoring the scanned values.
  Future<void> resetTrackMetadata(String trackId) async {
    if (!_overrides.containsKey(trackId)) return;
    await _persistOverrides({..._overrides}..remove(trackId));
  }

  /// Deletes the file, then removes every trace of the track.
  ///
  /// The cascade runs only after the media store confirms the delete — a cancelled system dialog
  /// must leave the library exactly as it was. A track id otherwise survives in six places, and a
  /// stale id in the queue means the player tries to load a file that is gone.
  Future<DeleteResult> deleteTrack(String trackId) async {
    final result = await media.deleteTrackFile(trackId);
    if (result != DeleteResult.deleted) return result;

    final remaining = _rawTracks.where((track) => track.id != trackId).toList();
    _update(() => _setRawTracks(remaining));
    await writeCachedLibrary(remaining, DateTime.now().millisecondsSinceEpoch);

    if (_overrides.containsKey(trackId)) {
      await _persistOverrides({..._overrides}..remove(trackId));
    }

    if (favorites.contains(trackId)) {
      _update(() => favorites = {...favorites}..remove(trackId));
      unawaited(writeCachedFavorites(favorites));
    }

    PlayCounts.instance.forget(trackId);
    media.forgetResolvedUri(trackId);
    await _engine.removeTrackFromQueue(trackId);

    return DeleteResult.deleted;
  }

  @override
  void dispose() {
    _disposed = true;
    _changeTimer?.cancel();
    _unsubscribeChanges?.call();
    super.dispose();
  }
}

extension LibraryContext on BuildContext {
  LibraryController get library => watch<LibraryController>();
  LibraryController get libraryActions => read<LibraryController>();
}
