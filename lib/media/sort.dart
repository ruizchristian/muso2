import '../core/text_compare.dart';
import 'track.dart';

/// Orders offered as chips. `title` is deliberately absent: it is the default the list falls back
/// to when the active chip is deselected, not something to pick.
const sortOptions = [
  (key: SortKey.addedAt, label: 'Time added'),
  (key: SortKey.playCount, label: 'Play count'),
];

/// Sort comparator for the three supported keys.
int Function(Track a, Track b) compareBySortKey(SortKey key, Map<String, int> playCounts) {
  switch (key) {
    case SortKey.addedAt:
      // Newest first — "time added" reads as most-recent-first everywhere else in the app.
      return (a, b) => b.addedAt.compareTo(a.addedAt);
    case SortKey.playCount:
      return (a, b) {
        final diff = (playCounts[b.id] ?? 0) - (playCounts[a.id] ?? 0);
        // Ties fall back to alphabetical so the order is stable rather than arbitrary.
        return diff != 0 ? diff : compareBaseInsensitive(a.title, b.title);
      };
    case SortKey.title:
      return (a, b) => compareBaseInsensitive(a.title, b.title);
  }
}
