import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../media/track.dart';
import '../../state/theme_controller.dart';
import '../../theme/layout.dart';
import '../widgets/app_icons.dart';
import '../widgets/artwork.dart';
import '../widgets/muso_text.dart';
import '../widgets/pressable_scale.dart';

const trackRowHeight = 60.0;
const _artworkSize = 44.0;

class TrackRow extends StatelessWidget {
  const TrackRow({
    super.key,
    required this.track,
    required this.onPress,
    this.isCurrent = false,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.onShowActions,
  });

  final Track track;

  /// Highlights the title and badges the artwork with an equaliser glyph.
  final bool isCurrent;
  final bool isFavorite;
  final ValueChanged<Track> onPress;
  final ValueChanged<String>? onToggleFavorite;

  /// Opens the row's action menu. Also bound to long-press.
  final ValueChanged<Track>? onShowActions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scrim = Colors.black.withValues(alpha: 0.45);

    return PressableScale(
      activeScale: 0.985,
      semanticLabel: '${track.title} by ${track.artist}',
      semanticHint: 'Plays this song',
      selected: isCurrent,
      onTap: () => onPress(track),
      // Long-press is the shortcut; the trailing button is the discoverable path, since a
      // long-press affordance is invisible to anyone not already looking for it.
      onLongPress: onShowActions == null ? null : () => onShowActions!(track),
      child: SizedBox(
        height: trackRowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              SizedBox.square(
                dimension: _artworkSize,
                child: Stack(
                  children: [
                    Artwork(
                      seed: trackSeed(track.album, track.artist),
                      size: _artworkSize,
                      coverIds: [track.id],
                    ),
                    if (onToggleFavorite != null)
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Semantics(
                          button: true,
                          selected: isFavorite,
                          label: isFavorite
                              ? 'Remove ${track.title} from favorites'
                              : 'Add ${track.title} to favorites',
                          excludeSemantics: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onToggleFavorite!(track.id),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: scrim,
                                borderRadius: const BorderRadius.only(
                                  bottomRight: Radius.circular(Radii.sm),
                                ),
                              ),
                              child: Icon(
                                isFavorite ? AppIcons.heartFilled : AppIcons.heart,
                                size: 13,
                                // Scrim behind it, so plain content colour reads on any tile.
                                color: isFavorite ? palette.accent : palette.content,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Opposite corner from the heart, so the two badges never collide.
                    if (isCurrent)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: scrim,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(Radii.sm),
                            ),
                          ),
                          child: Icon(AppIcons.equalizer, size: 13, color: palette.accent),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MusoText(
                      track.title,
                      variant: TextVariant.label,
                      maxLines: 1,
                      color: isCurrent ? palette.accent : palette.content,
                    ),
                    const SizedBox(height: 2),
                    MusoText(
                      track.artist,
                      variant: TextVariant.caption,
                      tone: TextTone.muted,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              MusoText(
                formatDuration(track.durationMs),
                variant: TextVariant.caption,
                tone: TextTone.faint,
              ),
              if (onShowActions != null)
                Semantics(
                  button: true,
                  label: 'More actions for ${track.title}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onShowActions!(track),
                    // Small glyph on a 60pt row: the padding is what makes the target reachable.
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 16, 4, 16),
                      child: Icon(AppIcons.more, size: 18, color: palette.faint),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
