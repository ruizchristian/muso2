import 'package:flutter/material.dart';

import '../../state/theme_controller.dart';
import '../../theme/layout.dart';
import 'pressable_scale.dart';

/// Pulsing placeholder. Static when the OS asks for reduced motion.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, required this.height, this.round = false});

  final double? width;
  final double height;
  final bool round;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
    lowerBound: 0.45,
    upperBound: 0.9,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reducedMotion(context)) {
      _controller
        ..stop()
        ..value = 0.45;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: _controller,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: context.palette.elevated,
            borderRadius: BorderRadius.circular(widget.round ? Radii.pill : Radii.sm),
          ),
        ),
      ),
    );
  }
}
