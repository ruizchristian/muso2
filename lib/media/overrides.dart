import 'track.dart';

typedef TrackOverrides = Map<String, TrackOverride>;

/// Layers user edits over scanned tracks.
///
/// Kept as one pure function with a single call site in the library controller on purpose. The
/// library is replaced wholesale by several independent paths — the cold-start cache, a manual
/// rescan, the staleness TTL, and the media-store change listener — and applying overrides at each
/// of them would mean every future path has to remember to do it too. Deriving the displayed list
/// from `(rawTracks, overrides)` instead makes forgetting structurally impossible.
///
/// Returns the original list when nothing is overridden, so the common case allocates nothing and
/// identity-keyed caches downstream do not invalidate.
List<Track> applyOverrides(List<Track> tracks, TrackOverrides overrides) {
  if (overrides.isEmpty) return tracks;

  var changed = false;

  final next = tracks.map((track) {
    final override = overrides[track.id];
    if (override == null) return track;

    changed = true;
    return track.copyWith(title: override.title, artist: override.artist, album: override.album);
  }).toList();

  return changed ? next : tracks;
}

/// Merges a patch into a track's override entry, dropping fields that match the scanned value.
///
/// Storing an "override" identical to what the scan produced would pin the value: a later rescan
/// that corrected the filename parsing could never surface, because the stale edit would keep
/// winning. Only genuine differences are kept.
TrackOverride? mergeOverride(Track scanned, TrackOverride? existing, TrackOverride patch) {
  String? pick(String? patchValue, String? existingValue, String scannedValue) {
    final value = (patchValue ?? existingValue)?.trim();
    return value != null && value.isNotEmpty && value != scannedValue ? value : null;
  }

  final cleaned = TrackOverride(
    title: pick(patch.title, existing?.title, scanned.title),
    artist: pick(patch.artist, existing?.artist, scanned.artist),
    album: pick(patch.album, existing?.album, scanned.album),
  );

  return cleaned.isEmpty ? null : cleaned;
}
