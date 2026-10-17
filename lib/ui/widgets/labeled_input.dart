import 'package:flutter/material.dart';

import '../../state/theme_controller.dart';
import '../../theme/layout.dart';
import 'muso_text.dart';

/// Labelled text field.
///
/// The label is a real, permanently visible label rather than a placeholder: a placeholder
/// disappears the moment someone starts typing, which leaves them no way to check what the field
/// was for — and leaves a screen reader with nothing to announce.
class LabeledInput extends StatelessWidget {
  const LabeledInput({
    super.key,
    required this.label,
    required this.controller,
    this.error,
    this.onChanged,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;

  /// Validation message. Its presence also drives the error styling.
  final String? error;
  final ValueChanged<String>? onChanged;
  final int? maxLength;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasError = error != null;

    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.card),
      borderSide: BorderSide(color: color),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MusoText(
          label,
          variant: TextVariant.label,
          tone: hasError ? TextTone.danger : TextTone.muted,
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          autocorrect: false,
          textCapitalization: textCapitalization,
          textInputAction: TextInputAction.done,
          inputFormatters: null,
          maxLength: maxLength,
          cursorColor: palette.accent,
          style: TextStyle(color: palette.content, fontSize: 16),
          decoration: InputDecoration(
            // The visible label above is the accessible name; the counter would be noise.
            counterText: '',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            filled: true,
            fillColor: hasError ? palette.danger.withValues(alpha: 0.05) : palette.elevated,
            enabledBorder: border(hasError ? palette.danger : palette.line),
            focusedBorder: border(hasError ? palette.danger : palette.accent),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          // Announced when it appears, without stealing focus from the field being corrected.
          Semantics(
            liveRegion: true,
            child: MusoText(error!, variant: TextVariant.caption, tone: TextTone.danger),
          ),
        ],
      ],
    );
  }
}
