import 'dart:math';

import 'package:flutter/material.dart';

import '../player/engine.dart';
import '../state/library_controller.dart';
import '../state/theme_controller.dart';
import '../ui/common/states.dart';
import '../ui/player/player_parts.dart';
import '../ui/widgets/app_icons.dart';
import '../ui/widgets/artwork.dart';
import '../ui/widgets/buttons.dart';
import '../ui/widgets/glass_panel.dart';
import '../ui/widgets/muso_text.dart';
import '../ui/widgets/pressable_scale.dart';

/// Drag distance past which releasing dismisses the sheet.
const _dismissThreshold = 140.0;
const _dismissVelocity = 900.0;

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with SingleTickerProviderStateMixin {
  bool _showQueue = false;
  double _dragOffset = 0;

  /// Springs the sheet back when a drag is released short of the threshold.
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..addListener(() => setState(() => _dragOffset = _settleFrom * (1 - _settle.value)));
  double _settleFrom = 0;

  void _dismiss() => Navigator.of(context).maybePop();

  void _onDragUpdate(DragUpdateDetails details) {
    if (reducedMotion(context)) return;
    _settle.stop();
    // Downward only — dragging up should not lift the sheet off the top of the screen.
    setState(() => _dragOffset = max(0, _dragOffset + details.delta.dy));
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragOffset > _dismissThreshold || details.velocity.pixelsPerSecond.dy > _dismissVelocity) {
      _dismiss();
      return;
    }

    _settleFrom = _dragOffset;
    _settle.forward(from: 0);
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.base,
      child: ValueListenableBuilder<PlaybackState>(
        valueListenable: PlayerEngine.instance.playback,
        builder: (context, playback, _) {
          final track = playback.currentTrack;

          if (track == null) {
            return EmptyState(
              title: 'Nothing playing',
              message: 'Pick a song from your library to get started.',
              actionLabel: 'Close',
              onAction: _dismiss,
            );
          }

          final seed = trackSeed(track.album, track.artist);
          final padding = MediaQuery.paddingOf(context);

          return GestureDetector(
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: ColoredBox(
                color: palette.base,
                child: Stack(
                  children: [
                    Positioned.fill(child: PlayerBackdrop(seed: seed)),
                    Column(
                      children: [
                        // The sheet is drag-to-dismiss; a grabber is the platform-standard
                        // affordance for that, and costs one box.
                        ExcludeSemantics(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: EdgeInsets.only(top: padding.top + 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      MusoIconButton(
                                        icon: AppIcons.chevronDown,
                                        semanticLabel: 'Close player',
                                        color: palette.content,
                                        onPressed: _dismiss,
                                      ),
                                      Expanded(
                                        child: MusoText(
                                          track.album,
                                          variant: TextVariant.overline,
                                          tone: TextTone.muted,
                                          maxLines: 1,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      MusoIconButton(
                                        icon: AppIcons.queue,
                                        semanticLabel: _showQueue ? 'Hide queue' : 'Show queue',
                                        active: _showQueue,
                                        onPressed: () => setState(() => _showQueue = !_showQueue),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: _showQueue
                                      ? _QueuePane(playback: playback)
                                      : _NowPlayingPane(playback: playback, seed: seed),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QueuePane extends StatelessWidget {
  const _QueuePane({required this.playback});

  final PlaybackState playback;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 16, bottom: 8),
          child: MusoText('Next in queue', variant: TextVariant.heading, header: true),
        ),
        Expanded(child: QueueList(playback: playback)),
      ],
    );
  }
}

class _NowPlayingPane extends StatelessWidget {
  const _NowPlayingPane({required this.playback, required this.seed});

  final PlaybackState playback;
  final String seed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final library = context.library;
    final track = playback.currentTrack!;
    final isFavorite = library.favorites.contains(track.id);
    final artGlow = context.artworkColorFor(seed);
    final size = MediaQuery.sizeOf(context);
    // Leave room for the header, metadata, controls, and safe areas.
    final artSize = min(size.width - 64, size.height * 0.42);

    final bottomPadding = MediaQuery.paddingOf(context).bottom + 16;

    // Centred in the available height, but still scrollable on a short screen rather than
    // overflowing.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: max(0, constraints.maxHeight - bottomPadding)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              // Bloom in the album's own colour.
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: artGlow.withValues(alpha: 0.6),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Artwork(seed: seed, size: artSize, gradient: true, coverIds: [track.id]),
              ),
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MusoText(track.title, variant: TextVariant.title, maxLines: 1),
                        const SizedBox(height: 4),
                        MusoText(track.artist, tone: TextTone.muted, maxLines: 1),
                      ],
                    ),
                  ),
                  MusoIconButton(
                    icon: isFavorite ? AppIcons.heartFilled : AppIcons.heart,
                    semanticLabel: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                    color: isFavorite ? palette.accent : palette.muted,
                    onPressed: () => library.toggleFavorite(track.id),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Scrubber and transport share one frosted slab, so they read as a single control
              // surface floating over the wash rather than as loose widgets on the page.
              GlassPanel(
                intensity: 35,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      PlaybackScrubber(fallbackDurationMs: track.durationMs),
                      const SizedBox(height: 20),
                      PlayerControls(playback: playback),
                    ],
                  ),
                ),
              ),
              if (playback.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: MusoText(
                    playback.error!,
                    tone: TextTone.danger,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
