import 'package:flutter/material.dart';

import '../core/format.dart';
import '../media/sort.dart';
import '../media/track.dart';
import '../player/engine.dart';
import '../player/play_counts.dart';
import '../state/library_controller.dart';
import '../ui/library/library_gate.dart';
import '../ui/library/library_widgets.dart';
import '../ui/library/track_list.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  // Edge-to-edge so the header wash reaches the status bar; LibraryHeader pays the inset.
  @override
  Widget build(BuildContext context) => const LibraryGate(child: _LibraryContent());
}

class _LibraryContent extends StatefulWidget {
  const _LibraryContent();

  @override
  State<_LibraryContent> createState() => _LibraryContentState();
}

class _LibraryContentState extends State<_LibraryContent> {
  SortKey _sortKey = SortKey.title;

  // Sorting 5,000 tracks is not free; recompute only when an input actually changed.
  List<Track>? _sorted;
  List<Track>? _sortedFrom;
  SortKey? _sortedBy;
  Map<String, int>? _sortedWithCounts;

  List<Track> _sortedTracks(List<Track> tracks, Map<String, int> playCounts) {
    // Play counts only affect the play-count order; ignoring them otherwise keeps a song starting
    // from re-sorting the list.
    final counts = _sortKey == SortKey.playCount ? playCounts : null;

    if (_sorted == null ||
        !identical(_sortedFrom, tracks) ||
        _sortedBy != _sortKey ||
        !identical(_sortedWithCounts, counts)) {
      _sorted = [...tracks]..sort(compareBySortKey(_sortKey, playCounts));
      _sortedFrom = tracks;
      _sortedBy = _sortKey;
      _sortedWithCounts = counts;
    }
    return _sorted!;
  }

  /// Selecting the active sort again clears it back to A–Z. `title` has no chip of its own, so
  /// without this the default order — and the A–Z index — would be gone after the first sort.
  void _handleSort(SortKey key) => setState(() => _sortKey = _sortKey == key ? SortKey.title : key);

  @override
  Widget build(BuildContext context) {
    final tracks = context.library.tracks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LibraryHeader(
          summary: '${formatCount(tracks.length)} songs',
          shuffleDisabled: tracks.isEmpty,
          onShuffle: () => PlayerEngine.instance.shufflePlay(tracks),
        ),
        SortChips(selected: _sortKey, onSelect: _handleSort),
        const SizedBox(height: 8),
        Expanded(
          child: ValueListenableBuilder<Map<String, int>>(
            valueListenable: PlayCounts.instance,
            builder: (context, playCounts, _) => TrackList(
              tracks: _sortedTracks(tracks, playCounts),
              // The index only makes sense in title order — under "time added" or "play count" a
              // letter would jump somewhere arbitrary.
              alphabetical: _sortKey == SortKey.title,
              // Deliberately the sort key, not the list: the list identity also changes when play
              // counts update, which would scroll to the top every time a song starts.
              scrollResetKey: _sortKey,
            ),
          ),
        ),
      ],
    );
  }
}
