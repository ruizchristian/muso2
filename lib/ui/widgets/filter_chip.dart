import 'package:flutter/material.dart';

import '../../state/theme_controller.dart';
import '../../theme/layout.dart';
import 'muso_text.dart';
import 'pressable_scale.dart';

enum ChipTone {
  /// The lit, accent-bloomed chip.
  primary,

  /// A secondary single-select group on the same screen, which must not compete with the primary.
  subtle,
}

/// Single-select pill. Announced as a member of a mutually exclusive group rather than as a plain
/// button, which would say nothing about which member is chosen.
class MusoFilterChip extends StatelessWidget {
  const MusoFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.tone = ChipTone.primary,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isPrimary = tone == ChipTone.primary;

    final labelColor = selected
        ? (isPrimary ? palette.accent : palette.glow)
        : (isPrimary ? palette.content : palette.muted);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: selected,
        child: PressableScale(
          semanticLabel: label,
          excludeChildSemantics: true,
          isButton: false,
          onTap: onPressed,
          builder: (context, pressed) => Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.pill),
              // Selected reads as tinted text on a raised surface. A solid fill would force the
              // label to `onAccent`, which is the one thing it must not be here.
              color: selected || pressed ? palette.pressed : palette.elevated,
              border: selected
                  ? Border.all(
                      color: isPrimary ? palette.accent : palette.glow.withValues(alpha: 0.6),
                    )
                  : null,
              // The selected primary chip blooms — the only lit thing on the screen, which is what
              // makes the state readable at a glance. Subtle chips never bloom.
              boxShadow: selected && isPrimary
                  ? [BoxShadow(color: palette.accent.withValues(alpha: 0.5), blurRadius: 10)]
                  : null,
            ),
            child: MusoText(
              label,
              variant: TextVariant.label,
              color: labelColor,
              fontWeight: selected ? FontWeight.w700 : null,
            ),
          ),
        ),
      ),
    );
  }
}
