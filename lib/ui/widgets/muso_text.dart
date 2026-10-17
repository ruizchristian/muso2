import 'package:flutter/material.dart';

import '../../state/theme_controller.dart';
import '../../theme/themes.dart';

enum TextVariant { display, title, heading, body, label, caption, overline }

enum TextTone { normal, muted, faint, accent, danger }

TextStyle textStyleFor(TextVariant variant) => switch (variant) {
  TextVariant.display => const TextStyle(
    fontSize: 32,
    height: 38 / 32,
    fontWeight: FontWeight.w800,
  ),
  TextVariant.title => const TextStyle(fontSize: 24, height: 32 / 24, fontWeight: FontWeight.w700),
  TextVariant.heading => const TextStyle(
    fontSize: 18,
    height: 28 / 18,
    fontWeight: FontWeight.w700,
  ),
  TextVariant.body => const TextStyle(fontSize: 16, height: 24 / 16),
  TextVariant.label => const TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w600),
  TextVariant.caption => const TextStyle(fontSize: 12, height: 16 / 12),
  TextVariant.overline => const TextStyle(
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
  ),
};

Color toneColor(Palette palette, TextTone tone) => switch (tone) {
  TextTone.normal => palette.content,
  TextTone.muted => palette.muted,
  TextTone.faint => palette.faint,
  TextTone.accent => palette.accent,
  TextTone.danger => palette.danger,
};

/// Themed text with the app's type scale. `color` overrides the tone when given.
class MusoText extends StatelessWidget {
  const MusoText(
    this.text, {
    super.key,
    this.variant = TextVariant.body,
    this.tone = TextTone.normal,
    this.color,
    this.fontWeight,
    this.fontSize,
    this.maxLines,
    this.textAlign,
    this.header = false,
  });

  final String text;
  final TextVariant variant;
  final TextTone tone;
  final Color? color;
  final FontWeight? fontWeight;
  final double? fontSize;
  final int? maxLines;
  final TextAlign? textAlign;

  /// Marks the text as a heading for screen readers.
  final bool header;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = textStyleFor(variant).copyWith(
      color: color ?? toneColor(palette, tone),
      fontWeight: fontWeight,
      fontSize: fontSize,
    );

    final widget = Text(
      variant == TextVariant.overline ? text.toUpperCase() : text,
      style: style,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      textAlign: textAlign,
    );

    return header ? Semantics(header: true, child: widget) : widget;
  }
}
