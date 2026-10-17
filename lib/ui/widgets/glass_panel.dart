import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../state/theme_controller.dart';
import '../../theme/layout.dart';

enum GlassTone {
  /// Neutral frosted pane. The default — use it for anything that is not a call to action.
  glass,

  /// Glow-rimmed pane, for the one surface on a screen that should pull the eye.
  neon,

  /// Accent-rimmed pane, for the primary action itself.
  hot,
}

/// Frosted pane with a hairline neon rim.
///
/// The glow lives on an unclipped outer box, because a clipped box cannot cast a shadow.
///
/// Only iOS gets a real backdrop blur, matching the RN app. On Android the panel sits on a nearly
/// opaque surface substrate instead: with nothing behind the tone fill, the pane read as
/// transparent and text over scrolling rows was unreadable. The rim and inner highlight still sell
/// it as glass, and it costs nothing on a mid-tier device.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.tone = GlassTone.glass,
    this.radius = Radii.lg,
    this.intensity = 40,
    this.glow = false,
    this.height,
  });

  final Widget child;
  final GlassTone tone;
  final double radius;

  /// Blur strength, 1-100. Lower reads as a thin membrane, higher as a solid frosted slab.
  final double intensity;

  /// Casts a coloured bloom behind the panel. Reserve it for the focal surface on a screen.
  final bool glow;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final glowColor = tone == GlassTone.hot ? palette.accent : palette.glow;
    final borderRadius = BorderRadius.circular(radius);
    final isIOS = Platform.isIOS;

    final (border, fill) = switch (tone) {
      GlassTone.glass => (
        Colors.white.withValues(alpha: 0.15),
        Colors.white.withValues(alpha: 0.06),
      ),
      GlassTone.neon => (
        palette.glow.withValues(alpha: 0.40),
        palette.glow.withValues(alpha: 0.07),
      ),
      GlassTone.hot => (
        palette.accent.withValues(alpha: 0.50),
        palette.accent.withValues(alpha: 0.10),
      ),
    };

    Widget pane = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: borderRadius,
        border: Border.all(color: border),
      ),
      child: Stack(
        children: [
          child,
          // Inner highlight along the top edge — what separates "frosted glass" from "grey box".
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 1,
            child: IgnorePointer(
              child: ColoredBox(color: glowColor.withValues(alpha: isIOS ? 0.5 : 0.35)),
            ),
          ),
        ],
      ),
    );

    if (isIOS) {
      final sigma = intensity / 100 * 24;
      pane = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: pane,
      );
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: isIOS ? null : palette.surface.withValues(alpha: 0.92),
        boxShadow: glow
            ? [BoxShadow(color: glowColor.withValues(alpha: 0.55), blurRadius: 18)]
            : null,
      ),
      child: ClipRRect(borderRadius: borderRadius, child: pane),
    );
  }
}
