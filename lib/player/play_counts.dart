import 'dart:async';

import 'package:flutter/foundation.dart';

import '../storage/persist.dart';

/// Per-track play tallies, keyed by track id. Missing key means zero.
///
/// Lives outside the widget tree because the playback engine — which is where a play actually
/// happens — is a plain object.
class PlayCounts extends ValueNotifier<Map<String, int>> {
  PlayCounts._() : super(const {});

  static final instance = PlayCounts._();

  /// A track counts as played once it has been listened to for this long, not on mere selection.
  static const thresholdMs = 15000;

  Timer? _persistTimer;
  bool _loaded = false;

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(seconds: 1), () {
      unawaited(writePersisted(StorageKeys.playCounts, {'counts': value}));
    });
  }

  /// Reads persisted tallies. Safe to call more than once; only the first load applies.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;

    final cached = await readPersisted(StorageKeys.playCounts, (json) {
      final raw = json['counts'];
      if (raw is! Map) return null;

      final counts = <String, int>{};
      for (final entry in raw.entries) {
        final count = entry.value;
        if (entry.key is! String || (entry.key as String).isEmpty) return null;
        if (count is! int || count < 0) return null;
        counts[entry.key as String] = count;
      }
      return counts;
    });

    if (cached != null) value = Map.unmodifiable(cached);
  }

  void record(String trackId) {
    value = Map.unmodifiable({...value, trackId: (value[trackId] ?? 0) + 1});
    _schedulePersist();
  }

  /// Drops a track's tally. Called when the underlying file is deleted.
  void forget(String trackId) {
    if (!value.containsKey(trackId)) return;

    value = Map.unmodifiable({...value}..remove(trackId));
    _schedulePersist();
  }
}
