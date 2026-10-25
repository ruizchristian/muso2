/// How many recent searches are kept. Older ones fall off the end.
const searchHistoryLimit = 10;

/// Puts `query` at the front of `history`. A repeat of an earlier search (ignoring case and
/// surrounding spaces) moves it up instead of listing it twice. Blank queries are ignored.
List<String> addToSearchHistory(List<String> history, String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return history;

  final key = trimmed.toLowerCase();
  return [
    trimmed,
    ...history.where((entry) => entry.toLowerCase() != key),
  ].take(searchHistoryLimit).toList();
}
