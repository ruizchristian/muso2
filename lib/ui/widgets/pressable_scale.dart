import 'package:flutter/material.dart';

/// Scale applied while a pressable is held.
const pressScale = 0.96;

bool reducedMotion(BuildContext context) => MediaQuery.disableAnimationsOf(context);

/// Tappable surface with a press-scale, the app's universal touch feedback.
///
/// The scale collapses to no motion when the user has asked the OS to reduce animations.
/// `builder` receives the pressed state for surfaces that also tint while held.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    this.child,
    this.builder,
    this.onTap,
    this.onLongPress,
    this.activeScale = pressScale,
    this.semanticLabel,
    this.semanticHint,
    this.selected,
    this.isButton = true,
    this.excludeChildSemantics = false,
  }) : assert(child != null || builder != null);

  final Widget? child;
  final Widget Function(BuildContext context, bool pressed)? builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Scale applied while held. Lower for larger surfaces.
  final double activeScale;
  final String? semanticLabel;
  final String? semanticHint;
  final bool? selected;
  final bool isButton;
  final bool excludeChildSemantics;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scale = _pressed && !reducedMotion(context) ? widget.activeScale : 1.0;

    return Semantics(
      button: widget.isButton,
      enabled: _enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      excludeSemantics: widget.excludeChildSemantics,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _setPressed(true) : null,
        onTapUp: _enabled ? (_) => _setPressed(false) : null,
        onTapCancel: _enabled ? () => _setPressed(false) : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _setPressed(false);
                widget.onLongPress!();
              },
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: widget.builder?.call(context, _pressed) ?? widget.child,
        ),
      ),
    );
  }
}
