import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/alphabet.dart';
import '../../media/track.dart';
import '../../player/engine.dart';
import '../../state/library_controller.dart';
import '../../state/theme_controller.dart';
import '../../theme/layout.dart';
import '../layout/layout_helpers.dart';
import '../widgets/muso_text.dart';
import 'track_actions.dart';
import 'track_row.dart';

/// Width of the A–Z strip. Lists pad their content by the same amount — the strip floats above
/// the rows, so without that inset a trailing duration renders underneath it.
const _alphabetStripWidth = 26.0;
const _letterHeight = 20.0;

/// Virtualised song list. Tapping a row makes the whole visible list the play queue, so "next"
/// continues through what the user was looking at.
class TrackList extends StatefulWidget {
  const TrackList({
    super.key,
    required this.tracks,
    this.alphabetical = false,
    this.header,
    this.empty,
    this.scrollResetKey,
  });

  final List<Track> tracks;

  /// Shows the A–Z jump strip. Only pass this when `tracks` is actually sorted by title: the index
  /// maps a letter to a row position, so any other order sends the user somewhere wrong.
  final bool alphabetical;
  final Widget? header;
  final Widget? empty;

  /// Scrolls back to the top whenever this value changes. Pass whatever identifies the current
  /// view (sort order); do NOT pass the track list, whose identity also changes on unrelated
  /// updates like play counts.
  final Object? scrollResetKey;

  @override
  State<TrackList> createState() => _TrackListState();
}

class _TrackListState extends State<TrackList> {
  final _controller = ScrollController();
  Map<String, int>? _letterIndex;

  @override
  void initState() {
    super.initState();
    _buildIndex();
  }

  @override
  void didUpdateWidget(TrackList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.tracks != widget.tracks || oldWidget.alphabetical != widget.alphabetical) {
      _buildIndex();
    }

    // Not animated — the content underneath has already been swapped out, so a scroll animation
    // would just be a blur through unrelated rows.
    if (oldWidget.scrollResetKey != widget.scrollResetKey && _controller.hasClients) {
      _controller.jumpTo(0);
    }
  }

  void _buildIndex() {
    _letterIndex = widget.alphabetical
        ? buildLetterIndex(widget.tracks, (track) => track.title)
        : null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handlePress(Track track) {
    // A search result can be tapped with the keyboard still up; dismiss it so the mini player is
    // not left lifted above a keyboard that is about to disappear.
    FocusManager.instance.primaryFocus?.unfocus();
    PlayerEngine.instance.playTracks(widget.tracks, widget.tracks.indexOf(track));
  }

  void _jumpToLetter(String letter) {
    final index = _letterIndex?[letter];
    if (index == null || !_controller.hasClients) return;

    // Not animated: tapping down the strip would otherwise queue animations behind the finger.
    _controller.jumpTo(min(index * trackRowHeight, _controller.position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    final library = context.library;
    final scrollPadding = scrollPaddingOf(context);
    final showIndex = _letterIndex != null && _letterIndex!.length > 1;
    final engine = PlayerEngine.instance;

    final list = ValueListenableBuilder<String?>(
      // Only the highlighted row matters here — listening to all playback state would repaint the
      // list on every play/pause.
      valueListenable: engine.currentTrackId,
      builder: (context, currentTrackId, _) => CustomScrollView(
        controller: _controller,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          if (widget.header != null) SliverToBoxAdapter(child: widget.header),
          if (widget.tracks.isEmpty && widget.empty != null)
            SliverFillRemaining(hasScrollBody: false, child: widget.empty)
          else
            SliverPadding(
              padding: EdgeInsets.only(right: showIndex ? _alphabetStripWidth : 0),
              sliver: SliverFixedExtentList(
                itemExtent: trackRowHeight,
                delegate: SliverChildBuilderDelegate((context, index) {
                  final track = widget.tracks[index];
                  return TrackRow(
                    key: ValueKey(track.id),
                    track: track,
                    isCurrent: track.id == currentTrackId,
                    isFavorite: library.favorites.contains(track.id),
                    onPress: _handlePress,
                    onToggleFavorite: library.toggleFavorite,
                    onShowActions: (track) => showTrackActions(context, track),
                  );
                }, childCount: widget.tracks.length),
              ),
            ),
          // Leave room for the mini player so the last row stays reachable.
          SliverToBoxAdapter(child: SizedBox(height: scrollPadding)),
        ],
      ),
    );

    if (!showIndex) return list;

    return Stack(
      children: [
        Positioned.fill(child: list),
        Positioned(
          right: 0,
          top: 0,
          // The lower part of the list is hidden behind the mini player; the strip stops above it.
          bottom: scrollPadding,
          width: _alphabetStripWidth,
          child: _AlphabetIndex(available: _letterIndex!.keys.toSet(), onSelect: _jumpToLetter),
        ),
      ],
    );
  }
}

/// Vertical A–Z strip, aligned to the top of the list it indexes. Only buckets that contain items
/// are shown — a full fixed A–Z would cram 27 rows into the space and leave most of them dead.
class _AlphabetIndex extends StatefulWidget {
  const _AlphabetIndex({required this.available, required this.onSelect});

  final Set<String> available;
  final ValueChanged<String> onSelect;

  @override
  State<_AlphabetIndex> createState() => _AlphabetIndexState();
}

class _AlphabetIndexState extends State<_AlphabetIndex> {
  String? _pressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final letters = indexLetters.where(widget.available.contains).toList();

    return Semantics(
      label: 'Jump to letter',
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            for (final letter in letters)
              Semantics(
                button: true,
                label: 'Jump to ${letter == '#' ? 'number' : letter}',
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => setState(() => _pressed = letter),
                  onTapCancel: () => setState(() => _pressed = null),
                  onTapUp: (_) => setState(() => _pressed = null),
                  onTap: () => widget.onSelect(letter),
                  child: Container(
                    height: _letterHeight,
                    width: _alphabetStripWidth,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _pressed == letter ? palette.pressed : null,
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: MusoText(
                      letter,
                      variant: TextVariant.caption,
                      fontSize: 11,
                      fontWeight: _pressed == letter ? FontWeight.w700 : null,
                      color: _pressed == letter ? palette.accent : palette.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
