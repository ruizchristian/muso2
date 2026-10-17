import 'text_compare.dart';

/// Every bucket the index strip can show, in display order. `#` collects everything
/// non-alphabetic.
const indexLetters = [
  '#',
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', //
  'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
];

/// The bucket a name belongs to.
///
/// Diacritics are folded first, so "Ángel" files under A rather than `#`. Leading articles are
/// deliberately NOT stripped — the list is sorted by raw title, and the index has to agree with
/// the order actually on screen or tapping a letter lands in the wrong place.
String bucketFor(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '#';

  final first = foldDiacritics(trimmed).toUpperCase()[0];
  final code = first.codeUnitAt(0);
  return code >= 65 && code <= 90 ? first : '#';
}

/// Maps each bucket to the index of its first item.
///
/// Assumes `items` is already sorted by the same name it is bucketed on — the caller only offers
/// the index when that holds.
Map<String, int> buildLetterIndex<T>(List<T> items, String Function(T item) getName) {
  final map = <String, int>{};

  for (var i = 0; i < items.length; i += 1) {
    // First occurrence wins: that is the row the letter should jump to.
    map.putIfAbsent(bucketFor(getName(items[i])), () => i);
  }

  return map;
}
