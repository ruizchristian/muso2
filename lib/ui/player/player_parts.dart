import 'package:flutter/material.dart' hide RepeatMode;

import '../../media/track.dart';
import '../../player/engine.dart';
import '../../state/theme_controller.dart';
import '../library/library_widgets.dart';
import '../library/track_row.dart';
import '../widgets/app_icons.dart';
import '../widgets/artwork.dart';
import '../widgets/buttons.dart';
import '../widgets/muso_text.dart';
import '../widgets/scrubber.dart';

/// Ambient wash behind the full-screen player, tinted by the current track, so changing track
/// visibly changes the room.
class PlayerBackdrop extends StatelessWidget {
  const PlayerBackdrop({super.key, required this.seed});

  /// Same seed the artwork tile uses, so the wash and the tile are always the same hue.
  final String seed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tint = context.artworkColorFor(seed);

    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: gradientPoint(0.15, 0),
            end: gradientPoint(0.9, 0.9),
            // Resolves to opaque `base` by the last stop, so the controls keep full text contrast
            // no matter how light the album's colour happens to be.
            colors: [
              tint.withValues(alpha: 0.5),
              palette.glow.withValues(alpha: 0.07),
              palette.base,
            ],
            stops: const [0, 0.45, 0.85],
          ),
        ),
      ),
    );
  }
}

/// Owns the progress subscription so the position tick rebuilds only the scrubber, not the
/// whole player screen.
class PlaybackScrubber extends StatelessWidget {
  const PlaybackScrubber({super.key, required this.fallbackDurationMs});

  /// Used until the player reports a real duration.
  final int fallbackDurationMs;

  @override
  Widget build(BuildContext context) {
    final engine = PlayerEngine.instance;

    return ValueListenableBuilder<ProgressState>(
      valueListenable: engine.progress,
      builder: (context, progress, _) => Scrubber(
        positionMs: progress.positionMs,
        durationMs: progress.durationMs > 0 ? progress.durationMs : fallbackDurationMs,
        onSeek: engine.seekTo,
      ),
    );
  }
}

const _repeatLabel = {
  RepeatMode.off: 'Repeat off. Tap to repeat the queue.',
  RepeatMode.all: 'Repeating the queue. Tap to repeat this song.',
  RepeatMode.one: 'Repeating this song. Tap to turn repeat off.',
};

/// The transport row: shuffle, previous, play/pause, next, repeat.
class PlayerControls extends StatelessWidget {
  const PlayerControls({super.key, required this.playback});

  final PlaybackState playback;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final engine = PlayerEngine.instance;

    final hasPrevious = playback.queue.isNotEmpty;
    final hasNext =
        playback.queue.isNotEmpty &&
        (playback.repeat != RepeatMode.off || playback.currentIndex < playback.queue.length - 1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        MusoIconButton(
          icon: AppIcons.shuffle,
          semanticLabel: playback.shuffle
              ? 'Shuffle on. Tap to turn off.'
              : 'Shuffle off. Tap to turn on.',
          active: playback.shuffle,
          onPressed: () => engine.setShuffle(!playback.shuffle),
        ),
        MusoIconButton(
          icon: AppIcons.previous,
          size: ControlSize.lg,
          semanticLabel: 'Previous song',
          color: palette.content,
          disabled: !hasPrevious,
          onPressed: engine.previous,
        ),
        MusoIconButton(
          icon: playback.isPlaying ? AppIcons.pause : AppIcons.play,
          variant: IconButtonVariant.filled,
          size: ControlSize.lg,
          semanticLabel: playback.isPlaying ? 'Pause' : 'Play',
          onPressed: engine.togglePlayPause,
        ),
        MusoIconButton(
          icon: AppIcons.next,
          size: ControlSize.lg,
          semanticLabel: 'Next song',
          color: palette.content,
          disabled: !hasNext,
          onPressed: engine.next,
        ),
        MusoIconButton(
          icon: playback.repeat == RepeatMode.one ? AppIcons.repeatOne : AppIcons.repeat,
          semanticLabel: _repeatLabel[playback.repeat]!,
          active: playback.repeat != RepeatMode.off,
          onPressed: engine.cycleRepeat,
        ),
      ],
    );
  }
}

/// "Next in queue" listing. Tapping a row jumps straight to it.
class QueueList extends StatelessWidget {
  const QueueList({super.key, required this.playback});

  final PlaybackState playback;

  @override
  Widget build(BuildContext context) {
    final start = playback.currentIndex + 1;
    final upNext = start < playback.queue.length ? playback.queue.sublist(start) : const <Track>[];

    if (upNext.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: MusoText(
          'Nothing else in the queue.',
          tone: TextTone.muted,
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      itemExtent: trackRowHeight,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      itemCount: upNext.length,
      itemBuilder: (context, index) => TrackRow(
        track: upNext[index],
        onPress: (_) => PlayerEngine.instance.skipToIndex(start + index),
      ),
    );
  }
}
