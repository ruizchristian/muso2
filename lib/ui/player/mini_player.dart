import 'dart:math';

import 'package:flutter/material.dart';

import '../../player/engine.dart';
import '../../routes.dart';
import '../../state/theme_controller.dart';
import '../../theme/layout.dart';
import '../widgets/app_icons.dart';
import '../widgets/artwork.dart';
import '../widgets/buttons.dart';
import '../widgets/muso_text.dart';
import '../widgets/pressable_scale.dart';

/// Persistent full-width bar resting directly on the tab bar. Mounted once above the navigator so it survives every
/// route change, and hidden wherever it would sit on top of something the user is working with:
/// the full-screen player, the edit form (whose fields and Save button it covered, and which it
/// followed up above the keyboard), and any sheet or dialog.
class MiniPlayerOverlay extends StatelessWidget {
  const MiniPlayerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = PlayerEngine.instance;
    final media = MediaQuery.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([routeTracker.topRoute, routeTracker.popupOpen]),
      builder: (context, _) {
        final route = routeTracker.topRoute.value;
        final hasTabBar = route == AppRoutes.tabs;
        final hidden =
            route == null ||
            route == AppRoutes.player ||
            route == AppRoutes.trackEdit ||
            routeTracker.popupOpen.value;

        // Flush on the tab bar where there is one, otherwise on the safe area. On the tab bar it
        // sinks over the bar's top border, so no line shows between the two.
        final resting = hasTabBar
            ? Layout.tabBarBaseHeight + media.padding.bottom - Layout.tabBarBorder
            : media.padding.bottom;
        // An open keyboard covers the tab bar entirely, so the bar rides on top of it instead.
        final bottom = max(resting, media.viewInsets.bottom);

        return ValueListenableBuilder<String?>(
          valueListenable: engine.currentTrackId,
          builder: (context, trackId, _) {
            final visible = trackId != null && !hidden;

            return Positioned(
              left: 0,
              right: 0,
              bottom: bottom,
              child: IgnorePointer(
                ignoring: !visible,
                child: AnimatedSlide(
                  offset: visible ? Offset.zero : const Offset(0, 0.4),
                  duration: Duration(milliseconds: reducedMotion(context) ? 0 : 220),
                  curve: Curves.easeOut,
                  child: AnimatedOpacity(
                    opacity: visible ? 1 : 0,
                    duration: Duration(milliseconds: reducedMotion(context) ? 0 : 200),
                    child: trackId == null ? const SizedBox.shrink() : const _MiniPlayer(),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final engine = PlayerEngine.instance;

    return ValueListenableBuilder<PlaybackState>(
      valueListenable: engine.playback,
      builder: (context, playback, _) {
        final track = playback.currentTrack;
        if (track == null) return const SizedBox.shrink();

        final seed = trackSeed(track.album, track.artist);
        final tint = context.artworkColorFor(seed);

        return PressableScale(
          // A full-width bar shrinking away from the screen edges looks broken, so it does not
          // scale on press.
          activeScale: 1,
          semanticLabel: 'Now playing: ${track.title} by ${track.artist}',
          semanticHint: 'Opens the full player',
          onTap: openPlayer,
          child: ColoredBox(
            color: palette.surface,
            child: SizedBox(
              height: Layout.miniPlayerHeight,
              child: Stack(
                children: [
                  // Album tint behind the content, cross-faded on track change. Low alpha: at full
                  // strength it would flood the bar.
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: reducedMotion(context) ? 0 : 320),
                      color: tint.withValues(alpha: 0.3),
                    ),
                  ),
                  // Top-edge highlight, the one line that separates the bar from the list behind.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 1,
                    child: ColoredBox(color: palette.glow.withValues(alpha: 0.35)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Artwork(seed: seed, size: 44, gradient: true, coverIds: [track.id]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MusoText(track.title, variant: TextVariant.label, maxLines: 1),
                              const SizedBox(height: 2),
                              MusoText(
                                playback.error ?? track.artist,
                                variant: TextVariant.caption,
                                tone: playback.error != null ? TextTone.danger : TextTone.muted,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        MusoIconButton(
                          icon: playback.isPlaying ? AppIcons.pause : AppIcons.play,
                          semanticLabel: playback.isPlaying ? 'Pause' : 'Play',
                          color: palette.content,
                          onPressed: engine.togglePlayPause,
                        ),
                        MusoIconButton(
                          icon: AppIcons.next,
                          semanticLabel: 'Next song',
                          color: palette.content,
                          onPressed: engine.next,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
