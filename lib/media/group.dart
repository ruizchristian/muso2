import '../core/format.dart';
import '../core/text_compare.dart';
import 'track.dart';

/// Stable, collision-resistant key for a grouping value.
String _keyFor(List<String> parts) => parts.map((part) => part.toLowerCase()).join('::');

int _byName(TrackGroup a, TrackGroup b) => compareBaseInsensitive(a.name, b.name);

/// Groups tracks into albums, keyed by album + artist so two different artists' "Greatest Hits"
/// stay separate.
List<TrackGroup> groupByAlbum(List<Track> tracks) {
  final groups = <String, TrackGroup>{};

  for (final track in tracks) {
    final id = _keyFor([track.album, track.artist]);
    final existing = groups[id];

    if (existing != null) {
      existing.tracks.add(track);
    } else {
      groups[id] = TrackGroup(id: id, name: track.album, subtitle: track.artist, tracks: [track]);
    }
  }

  return groups.values.toList()..sort(_byName);
}

List<TrackGroup> groupByArtist(List<Track> tracks) {
  final groups = <String, TrackGroup>{};

  for (final track in tracks) {
    final id = _keyFor([track.artist]);
    final existing = groups[id];

    if (existing != null) {
      existing.tracks.add(track);
    } else {
      groups[id] = TrackGroup(id: id, name: track.artist, subtitle: '', tracks: [track]);
    }
  }

  // `subtitle` is a song count, so it can only be filled once every track has been visited.
  for (final group in groups.values) {
    group.subtitle = pluralize(group.tracks.length, 'song');
  }

  return groups.values.toList()..sort(_byName);
}

/// Case-insensitive substring match across title, artist, and album.
List<Track> searchTracks(List<Track> tracks, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const [];

  return tracks
      .where(
        (track) =>
            track.title.toLowerCase().contains(needle) ||
            track.artist.toLowerCase().contains(needle) ||
            track.album.toLowerCase().contains(needle),
      )
      .toList();
}
