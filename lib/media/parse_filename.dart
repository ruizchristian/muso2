/// Derives display metadata from a filename.
///
/// The media store exposes no ID3/embedded tags, so filename conventions are the only metadata
/// available without decoding every file. Recognised shapes, in order:
///
///   `Artist - Album - Title.mp3`
///   `Artist - Title.mp3`
///   `01 Title.mp3` / `01 - Title.mp3`
///   `Title.mp3`
///
/// A leading track number is stripped in every case.
library;

final _audioExtension = RegExp(r'\.[a-z0-9]{1,5}$', caseSensitive: false);
final _leadingTrackNumber = RegExp(r'^\s*\d{1,3}\s*[-._)]?\s+');
final _separator = RegExp(r'\s+-\s+');
final _underscores = RegExp(r'_+');
final _whitespace = RegExp(r'\s+');

const unknownArtist = 'Unknown artist';
const unknownAlbum = 'Unknown album';

typedef ParsedFilename = ({String title, String artist, String album});

String _tidy(String value) =>
    value.replaceAll(_underscores, ' ').replaceAll(_whitespace, ' ').trim();

ParsedFilename parseFilename(String filename) {
  final withoutExtension = filename.replaceFirst(_audioExtension, '');
  final stripped = _tidy(withoutExtension.replaceFirst(_leadingTrackNumber, ''));

  // Everything failed to produce a usable name — fall back to the raw filename.
  final tidiedRaw = _tidy(withoutExtension);
  final fallbackTitle = stripped.isNotEmpty
      ? stripped
      : tidiedRaw.isNotEmpty
      ? tidiedRaw
      : filename;

  final parts = stripped.split(_separator).map(_tidy).where((part) => part.isNotEmpty).toList();

  if (parts.length >= 3) {
    return (
      artist: parts[0],
      album: parts[1],
      // Re-join any trailing separators so "A - B - C - D" keeps "C - D" as the title.
      title: parts.sublist(2).join(' - '),
    );
  }

  if (parts.length == 2) {
    return (artist: parts[0], album: unknownAlbum, title: parts[1]);
  }

  return (artist: unknownArtist, album: unknownAlbum, title: fallbackTitle);
}
