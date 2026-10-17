import 'package:flutter/material.dart';

import '../../media/sort.dart';
import '../../media/track.dart';
import '../../routes.dart';
import '../../state/theme_controller.dart';
import '../layout/layout_helpers.dart';
import '../widgets/app_icons.dart';
import '../widgets/artwork.dart';
import '../widgets/buttons.dart';
import '../widgets/filter_chip.dart';
import '../widgets/muso_text.dart';
import '../widgets/pressable_scale.dart';

const albumCardWidth = 148.0;

/// Converts the RN app's gradient `start`/`end` points (0–1 per axis) to Flutter alignments.
Alignment gradientPoint(double x, double y) => Alignment(x * 2 - 1, y * 2 - 1);

class AlbumCard extends StatelessWidget {
  const AlbumCard({super.key, required this.album});

  final TrackGroup album;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: PressableScale(
        semanticLabel: '${album.name} by ${album.subtitle}',
        excludeChildSemantics: true,
        onTap: () => navigatorKey.currentState?.pushNamed(AppRoutes.album, arguments: album.id),
        child: SizedBox(
          width: albumCardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Artwork(
                seed: album.id,
                size: albumCardWidth,
                kind: ArtworkKind.album,
                gradient: true,
              ),
              const SizedBox(height: 8),
              MusoText(album.name, variant: TextVariant.label, maxLines: 1),
              const SizedBox(height: 2),
              MusoText(
                album.subtitle,
                variant: TextVariant.caption,
                tone: TextTone.muted,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Masthead for the library, matching the home screen's so switching tabs reads as moving within
/// one app rather than between two.
class LibraryHeader extends StatelessWidget {
  const LibraryHeader({
    super.key,
    required this.summary,
    required this.onShuffle,
    required this.shuffleDisabled,
  });

  /// Count line for what the list is showing.
  final String summary;
  final VoidCallback onShuffle;

  /// Nothing to shuffle — the library is empty.
  final bool shuffleDisabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          // Mirrored against the home hero's angle, so the two masts are a pair rather than a
          // repeat — same family, different light.
          begin: gradientPoint(0.9, 0),
          end: gradientPoint(0.1, 1),
          colors: [
            palette.glow.withValues(alpha: 0.22),
            palette.accent.withValues(alpha: 0.10),
            Colors.transparent,
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: ContentContainer(
          top: 12,
          bottom: 16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MusoText(summary, variant: TextVariant.overline, tone: TextTone.accent),
                    const SizedBox(height: 4),
                    const MusoText('Your Library', variant: TextVariant.display, header: true),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              MusoButton(
                label: 'Shuffle',
                size: ControlSize.sm,
                disabled: shuffleDisabled,
                onPressed: onShuffle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sort order, inline beneath the header. Scrollable because the labels plus the lead-in overflow
/// a narrow phone, and truncating "Play count" to fit would defeat the point.
class SortChips extends StatelessWidget {
  const SortChips({super.key, required this.selected, required this.onSelect});

  final SortKey selected;
  final ValueChanged<SortKey> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      label: 'Sort by',
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            // Pinned outside the scroller so the group always says what it is.
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Row(
                children: [
                  Icon(AppIcons.sort, size: 14, color: palette.faint),
                  const SizedBox(width: 4),
                  const MusoText('Sort', variant: TextVariant.overline, tone: TextTone.faint),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    for (final option in sortOptions)
                      MusoFilterChip(
                        tone: ChipTone.subtle,
                        label: option.label,
                        selected: option.key == selected,
                        onPressed: () => onSelect(option.key),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
