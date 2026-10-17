import 'package:flutter/material.dart';

import '../../state/theme_controller.dart';
import '../../theme/layout.dart';
import 'pressable_scale.dart';

enum ButtonVariant { primary, secondary, outline, ghost }

enum ControlSize { sm, md, lg }

/// Pill-shaped text button.
class MusoButton extends StatelessWidget {
  const MusoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ControlSize.md,
    this.block = false,
    this.loading = false,
    this.disabled = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ControlSize size;
  final bool block;
  final bool loading;
  final bool disabled;

  /// Rendered before the label.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final inactive = disabled || loading || onPressed == null;

    final (height, padding, fontSize) = switch (size) {
      ControlSize.sm => (32.0, 16.0, 12.0),
      ControlSize.md => (44.0, 24.0, 14.0),
      ControlSize.lg => (56.0, 32.0, 16.0),
    };

    // `onAccent` rather than literal black: what reads on a filled button is theme-dependent.
    final labelColor = switch (variant) {
      ButtonVariant.primary => palette.onAccent,
      ButtonVariant.secondary || ButtonVariant.outline => palette.content,
      ButtonVariant.ghost => palette.muted,
    };

    return Opacity(
      opacity: inactive && !loading ? 0.5 : 1,
      child: PressableScale(
        semanticLabel: label,
        excludeChildSemantics: true,
        onTap: inactive ? null : onPressed,
        builder: (context, pressed) {
          final background = switch (variant) {
            ButtonVariant.primary => pressed ? palette.accentPress : palette.accent,
            ButtonVariant.secondary => pressed ? palette.pressed : palette.elevated,
            ButtonVariant.outline || ButtonVariant.ghost => Colors.transparent,
          };

          return Container(
            height: height,
            width: block ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: padding),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(Radii.pill),
              border: variant == ButtonVariant.outline ? Border.all(color: palette.muted) : null,
            ),
            child: Row(
              mainAxisSize: block ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: labelColor),
                  )
                else ...[
                  if (icon != null) ...[
                    Icon(icon, size: fontSize + 4, color: labelColor),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

enum IconButtonVariant { plain, filled, subtle }

/// Round icon-only control. `semanticLabel` is required — an icon has no visible text to announce.
class MusoIconButton extends StatelessWidget {
  const MusoIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.variant = IconButtonVariant.plain,
    this.size = ControlSize.md,
    this.color,
    this.disabled = false,
    this.active = false,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final IconButtonVariant variant;
  final ControlSize size;
  final Color? color;
  final bool disabled;

  /// Marks the control as on (e.g. shuffle enabled), which tints it and sets selected state.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final glyphColor =
        color ??
        (variant == IconButtonVariant.filled
            ? palette.onAccent
            : active
            ? palette.accent
            : palette.muted);

    final (box, glyph) = switch (size) {
      ControlSize.sm => (32.0, 18.0),
      ControlSize.md => (44.0, 24.0),
      ControlSize.lg => (64.0, 30.0),
    };

    return Opacity(
      opacity: disabled ? 0.4 : 1,
      child: PressableScale(
        semanticLabel: semanticLabel,
        selected: active,
        excludeChildSemantics: true,
        onTap: disabled ? null : onPressed,
        builder: (context, pressed) => Container(
          width: box,
          height: box,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: switch (variant) {
              IconButtonVariant.plain => Colors.transparent,
              IconButtonVariant.filled => palette.content,
              IconButtonVariant.subtle => pressed ? palette.pressed : palette.elevated,
            },
          ),
          child: Icon(icon, size: glyph, color: glyphColor),
        ),
      ),
    );
  }
}
