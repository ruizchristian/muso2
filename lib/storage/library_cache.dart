import '../media/overrides.dart';
import '../media/track.dart';
import 'persist.dart';

/// Strict list parse: any malformed entry rejects the whole document, matching the RN app's
/// schema validation (a half-valid cache is worse than a rescan).
List<T>? _parseList<T>(Object? raw, T? Function(Object? item) parse) {
  if (raw is! List) return null;

  final result = <T>[];
  for (final item in raw) {
    final parsed = parse(item);
    if (parsed == null) return null;
    result.add(parsed);
  }
  return result;
}

String? _id(Object? value) => value is String && value.isNotEmpty ? value : null;

typedef CachedLibrary = ({List<Track> tracks, int scannedAt});

/// Cached tracks plus when they were scanned, for staleness checks at startup.
Future<CachedLibrary?> readCachedLibrary() => readPersisted(StorageKeys.library, (json) {
  final tracks = _parseList(json['tracks'], Track.tryParse);
  final scannedAt = json['scannedAt'];
  if (tracks == null || scannedAt is! num || scannedAt < 0) return null;
  return (tracks: tracks, scannedAt: scannedAt.round());
});

Future<void> writeCachedLibrary(List<Track> tracks, int scannedAt) =>
    writePersisted(StorageKeys.library, {
      'tracks': [for (final track in tracks) track.toJson()],
      'scannedAt': scannedAt,
    });

/// What survives a restart of the playback session.
class PersistedPlayback {
  const PersistedPlayback({
    required this.queue,
    required this.currentIndex,
    required this.positionMs,
    required this.shuffle,
    required this.repeat,
  });

  /// Track ids, in the order they should play.
  final List<String> queue;
  final int currentIndex;
  final int positionMs;
  final bool shuffle;
  final RepeatMode repeat;
}

Future<PersistedPlayback?> readCachedPlayback() => readPersisted(StorageKeys.playback, (json) {
  final queue = _parseList(json['queue'], _id);
  final currentIndex = json['currentIndex'];
  final positionMs = json['positionMs'];
  final shuffle = json['shuffle'];
  final repeat = RepeatMode.values.asNameMap()[json['repeat']];

  if (queue == null ||
      currentIndex is! int ||
      currentIndex < 0 ||
      positionMs is! num ||
      positionMs < 0 ||
      shuffle is! bool ||
      repeat == null) {
    return null;
  }

  return PersistedPlayback(
    queue: queue,
    currentIndex: currentIndex,
    positionMs: positionMs.round(),
    shuffle: shuffle,
    repeat: repeat,
  );
});

Future<void> writeCachedPlayback(PersistedPlayback playback) =>
    writePersisted(StorageKeys.playback, {
      'queue': playback.queue,
      'currentIndex': playback.currentIndex,
      'positionMs': playback.positionMs,
      'shuffle': playback.shuffle,
      'repeat': playback.repeat.name,
    });

Future<List<String>> readCachedFavorites() async =>
    await readPersisted(StorageKeys.favorites, (json) => _parseList(json['trackIds'], _id)) ??
    const [];

Future<void> writeCachedFavorites(Iterable<String> trackIds) =>
    writePersisted(StorageKeys.favorites, {'trackIds': trackIds.toList()});

Future<TrackOverrides> readTrackOverrides() async =>
    await readPersisted(StorageKeys.overrides, (json) {
      final raw = json['overrides'];
      if (raw is! Map) return null;

      final result = <String, TrackOverride>{};
      for (final entry in raw.entries) {
        final id = _id(entry.key);
        final override = TrackOverride.tryParse(entry.value);
        if (id == null || override == null) return null;
        result[id] = override;
      }
      return result;
    }) ??
    {};

Future<void> writeTrackOverrides(TrackOverrides overrides) async {
  // An empty map is removed rather than stored, so a user who resets everything leaves no trace.
  if (overrides.isEmpty) {
    await removePersisted(StorageKeys.overrides);
    return;
  }

  await writePersisted(StorageKeys.overrides, {
    'overrides': {for (final entry in overrides.entries) entry.key: entry.value.toJson()},
  });
}
