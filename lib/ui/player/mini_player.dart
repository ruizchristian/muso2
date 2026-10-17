import 'dart:math';

import 'package:flutter/material.dart';

import '../../player/engine.dart';
import '../../routes.dart';
import '../../state/theme_controller.dart';
import '../../theme/layout.dart';
import '../widgets/app_icons.dart';
import '../widgets/artwork.dart';
import '../widgets/buttons.dart';
import '../widgets/glass_panel.dart';
import '../widgets/muso_text.dart';
import '../widgets/pressable_scale.dart';

/// Persistent capsule above the tab bar. Mounted once above the navigator so it survives every
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

        // Clear of the tab bar where there is one, otherwise clear of the safe area — plus the gap
        // a floating capsule needs.
        final resting =
            (hasTabBar ? Layout.tabBarBaseHeight : 0) + media.padding.bottom + Layout.miniPlayerGap;
        // An open keyboard covers the tab bar entirely, so the capsule rides on top of it instead.
        final bottom = max(resting, media.viewInsets.bottom + Layout.miniPlayerGap);

        return ValueListenableBuilder<String?>(
          valueListenable: engine.currentTrackId,
          builder: (context, trackId, _) {
            final visible = trackId != null && !hidden;

            return Positioned(
              left: 12,
              right: 12,
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
          activeScale: 0.98,
          semanticLabel: 'Now playing: ${track.title} by ${track.artist}',
          semanticHint: 'Opens the full player',
          onTap: openPlayer,
          child: GlassPanel(
            glow: true,
            intensity: 45,
            height: Layout.miniPlayerHeight,
            child: SizedBox(
              height: Layout.miniPlayerHeight - 2,
              child: Stack(
                children: [
                  // Album tint behind the content, cross-faded on track change. Low alpha: at full
                  // strength it would flood the capsule and there would be no glass left to see.
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: reducedMotion(context) ? 0 : 320),
                      color: tint.withValues(alpha: 0.3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Artwork(seed: seed, size: 44, gradient: true),
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
                  // Neon hairline along the bottom edge, clipped by the capsule's own radius so
                  // it tapers into the corners instead of running past them.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 2,
                    child: ExcludeSemantics(
                      child: ValueListenableBuilder<ProgressState>(
                        valueListenable: engine.progress,
                        builder: (context, progress, _) {
                          final fraction = progress.durationMs > 0
                              ? min(1.0, progress.positionMs / progress.durationMs)
                              : 0.0;

                          return ColoredBox(
                            color: Colors.white.withValues(alpha: 0.1),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: fraction,
                              child: ColoredBox(color: palette.glow),
                            ),
                          );
                        },
                      ),
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
