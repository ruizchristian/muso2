import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import 'parse_filename.dart';
import 'track.dart';

/// Everything that touches the device media store.
///
/// `photo_manager` does the querying, change notification and deletion; `permission_handler`
/// owns the permission state, because it can tell "denied" apart from "denied permanently" and
/// `photo_manager` cannot.

enum AudioPermissionState {
  undetermined,
  granted,

  /// Denied, but the OS will still show the prompt again.
  denied,

  /// Denied permanently — only a trip to Settings can recover.
  blocked,
}

/// Outcome of a delete attempt. `cancelled` is a user choice, not an error.
enum DeleteResult { deleted, cancelled, failed }

/// True on the platforms where there is an on-device media store to read.
bool get isMediaSupported => Platform.isAndroid || Platform.isIOS;

Permission? _audioPermission;

/// Android 13 split storage access per media type: `READ_MEDIA_AUDIO` from SDK 33, the old
/// storage permission before that. Asking for the wrong one either does nothing or prompts for
/// photos too, so the SDK level decides.
Future<Permission> _permissionForPlatform() async {
  if (_audioPermission != null) return _audioPermission!;

  if (Platform.isAndroid) {
    final info = await DeviceInfoPlugin().androidInfo;
    _audioPermission = info.version.sdkInt >= 33 ? Permission.audio : Permission.storage;
  } else {
    _audioPermission = Permission.mediaLibrary;
  }
  return _audioPermission!;
}

AudioPermissionState _toState(PermissionStatus status, {required bool afterRequest}) {
  if (status.isGranted || status.isLimited) return AudioPermissionState.granted;
  if (status.isPermanentlyDenied || status.isRestricted) return AudioPermissionState.blocked;
  // Before any request, Android reports plain "denied" for a permission it has never asked about.
  return afterRequest ? AudioPermissionState.denied : AudioPermissionState.undetermined;
}

/// Reads the current state without prompting.
Future<AudioPermissionState> getAudioPermission() async {
  final permission = await _permissionForPlatform();
  return _toState(await permission.status, afterRequest: false);
}

/// Prompts for read access to on-device audio only. On Android 13+ this maps to
/// `READ_MEDIA_AUDIO`, so the user is never asked for photos or video.
Future<AudioPermissionState> requestAudioPermission() async {
  final permission = await _permissionForPlatform();
  return _toState(await permission.request(), afterRequest: true);
}

/// Deep-links into the OS settings page for this app, for the `blocked` case.
Future<void> openSystemSettings() => openAppSettings();

const _minDurationMs = 30000;
const _excludedPathHints = ['ringtone', 'notification', 'alarm', 'ui/', 'whatsapp voice'];
const _pageSize = 500;
const _maxTracks = 20000;

bool _isLikelyMusic(String filename, int durationMs) {
  if (durationMs < _minDurationMs) return false;

  final haystack = filename.toLowerCase();
  return !_excludedPathHints.any(haystack.contains);
}

/// Builds a `Track` from a media-store row, or null when the row is not music or is malformed.
/// A bad row is skipped, never thrown on — one bad file must not empty the library.
Track? _toTrack(AssetEntity asset) {
  final filename = asset.title?.trim();
  // The media store reports audio duration in whole seconds.
  final durationMs = asset.duration * 1000;
  if (filename == null || filename.isEmpty || !_isLikelyMusic(filename, durationMs)) return null;

  final parsed = parseFilename(filename);
  final addedSeconds = asset.createDateSecond ?? asset.modifiedDateSecond ?? 0;

  return Track(
    id: asset.id,
    title: parsed.title,
    artist: parsed.artist,
    album: parsed.album,
    durationMs: durationMs,
    filename: filename,
    addedAt: addedSeconds * 1000,
  );
}

bool _configured = false;

Future<void> _ensureConfigured() async {
  if (_configured) return;
  _configured = true;
  // Permission is owned by `permission_handler` above; without this, photo_manager runs its own
  // check and can prompt for the wrong media types.
  await PhotoManager.setIgnorePermissionCheck(true);
}

/// Reads every audio asset from the device media store, newest first.
Future<List<Track>> scanAudioLibrary({void Function(int found)? onProgress}) async {
  await _ensureConfigured();

  final paths = await PhotoManager.getAssetPathList(
    type: RequestType.audio,
    onlyAll: true,
    filterOption: FilterOptionGroup(
      orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
    ),
  );
  if (paths.isEmpty) return [];

  final all = paths.first;
  final tracks = <Track>[];
  final seen = <String>{};

  for (var page = 0; page * _pageSize < _maxTracks; page += 1) {
    final assets = await all.getAssetListPaged(page: page, size: _pageSize);
    if (assets.isEmpty) break;

    for (final asset in assets) {
      if (!seen.add(asset.id)) continue;
      final track = _toTrack(asset);
      if (track != null) tracks.add(track);
    }

    onProgress?.call(tracks.length);
    if (assets.length < _pageSize) break;
  }

  return tracks;
}

/// Subscribes to media-store changes so the app can rescan on an actual edit instead of polling or
/// rescanning at every launch. Returns an unsubscribe function.
Future<void Function()> subscribeToMediaChanges(void Function() onChange) async {
  try {
    await _ensureConfigured();

    void listener(MethodCall _) => onChange();
    PhotoManager.addChangeCallback(listener);
    await PhotoManager.startChangeNotify();

    return () {
      PhotoManager.removeChangeCallback(listener);
      unawaited(PhotoManager.stopChangeNotify());
    };
  } catch (_) {
    // No listener support here — callers fall back to the staleness check.
    return () {};
  }
}

final _uriCache = <String, String>{};
final _uriInFlight = <String, Future<String?>>{};

/// Resolves a track to a playable URI (a `content://` URI on Android).
///
/// Memoised because the same track is normally played and re-queued several times per session.
Future<String?> resolveTrackUri(Track track) {
  final known = track.uri ?? _uriCache[track.id];
  if (known != null) return Future.value(known);

  return _uriInFlight[track.id] ??= () async {
    try {
      final asset = await AssetEntity.fromId(track.id);
      final uri = await asset?.getMediaUrl();
      if (uri != null) _uriCache[track.id] = uri;
      return uri;
    } catch (_) {
      // The file was moved or deleted since the last scan. The caller skips the track.
      return null;
    } finally {
      // Runs after the first await, so the `??=` below has already stored this future.
      _uriInFlight.remove(track.id);
    }
  }();
}

/// Drops memoised URIs — call after a rescan so moved files are re-resolved.
void clearResolvedUris() => _uriCache.clear();

/// Drops one track's memoised URI. Used after a delete, where clearing the whole cache would force
/// every other queued track through a native round-trip again for no reason.
void forgetResolvedUri(String trackId) {
  _uriCache.remove(trackId);
  _uriInFlight.remove(trackId);
}

/// Permanently removes an asset's file from device storage.
///
/// On Android 11+ the system shows its own confirmation dialog for files the app does not own. An
/// empty result or a throw is treated as `cancelled` rather than as failure: reporting "delete
/// failed" to someone who just pressed Deny would be wrong, and the caller's cascade is skipped
/// either way.
Future<DeleteResult> deleteTrackFile(String trackId) async {
  if (!isMediaSupported) return DeleteResult.failed;

  try {
    final deleted = await PhotoManager.editor.deleteWithIds([trackId]);
    return deleted.contains(trackId) ? DeleteResult.deleted : DeleteResult.cancelled;
  } catch (_) {
    // Deliberately swallowed: a media-store error message can embed the full file path, which
    // must not reach the UI or a log.
    return DeleteResult.cancelled;
  }
}
