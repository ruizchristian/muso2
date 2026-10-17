/// Folds common Latin diacritics onto their base letter, so "Ángel" sorts and buckets beside
/// "Angel". Dart has no built-in Unicode normaliser, and this covers the accents that actually
/// show up in music filenames without pulling in a dependency.
String foldDiacritics(String input) {
  final buffer = StringBuffer();

  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_folds[char] ?? char);
  }

  return buffer.toString();
}

/// Case- and accent-insensitive comparison — the equivalent of
/// `localeCompare(b, undefined, { sensitivity: 'base' })`.
int compareBaseInsensitive(String a, String b) {
  final folded = foldDiacritics(a).toLowerCase().compareTo(foldDiacritics(b).toLowerCase());
  return folded;
}

const _foldSource = {
  'a': 'àáâãäåāăą',
  'A': 'ÀÁÂÃÄÅĀĂĄ',
  'c': 'çćĉċč',
  'C': 'ÇĆĈĊČ',
  'd': 'ďđ',
  'D': 'ĎĐ',
  'e': 'èéêëēĕėęě',
  'E': 'ÈÉÊËĒĔĖĘĚ',
  'g': 'ĝğġģ',
  'G': 'ĜĞĠĢ',
  'i': 'ìíîïĩīĭįı',
  'I': 'ÌÍÎÏĨĪĬĮİ',
  'n': 'ñńņňŉ',
  'N': 'ÑŃŅŇ',
  'o': 'òóôõöøōŏő',
  'O': 'ÒÓÔÕÖØŌŎŐ',
  's': 'śŝşšß',
  'S': 'ŚŜŞŠ',
  'u': 'ùúûüũūŭůűų',
  'U': 'ÙÚÛÜŨŪŬŮŰŲ',
  'y': 'ýÿŷ',
  'Y': 'ÝŸŶ',
  'z': 'źżž',
  'Z': 'ŹŻŽ',
};

final Map<String, String> _folds = {
  for (final entry in _foldSource.entries)
    for (final char in entry.value.split('')) char: entry.key,
};
