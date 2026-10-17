import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/color.dart';
import '../../state/theme_controller.dart';
import '../../theme/layout.dart';
import 'app_icons.dart';

/// Stable string hash (djb2, 32-bit like the RN app). Same key always maps to the same colour, so
/// an album keeps its colour across both apps.
int _hash(String key) {
  var value = 5381;
  for (final unit in key.codeUnits) {
    value = (((value << 5) + value) + unit).toSigned(32);
  }
  return value.abs();
}

/// Picks a seed's tile colour out of the active theme's ramp.
///
/// Public so surfaces outside the tile — the mini player and detail headers — can tint themselves
/// to match the album they belong to.
Color artworkColor(String seed, List<Color> ramp) => ramp[_hash(seed) % ramp.length];

extension ArtworkColorContext on BuildContext {
  Color artworkColorFor(String seed) => artworkColor(seed, musoTheme.artwork);
}

/// The seed every surface uses for a track, so its tile, mini player and backdrop always match.
String trackSeed(String album, String artist) => '$album:$artist';

/// What the tile stands for. Drives the fallback's shape, glyph and decoration, so a caller states
/// what the thing *is* rather than how it should look.
enum ArtworkKind { track, album, artist }

/// Artwork tile.
///
/// The media store exposes no embedded cover art, so rather than an identical grey square
/// everywhere, the tile is a colour derived deterministically from the album key — the same album
/// always gets the same colour, which makes grids scannable.
///
/// `gradient` opts large tiles into a decorated form; it is off by default because it costs
/// several extra layers per tile, and the detail is illegible much below 56px anyway.
class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.seed,
    required this.size,
    this.kind = ArtworkKind.track,
    this.gradient = false,
  });

  final String seed;
  final double size;
  final ArtworkKind kind;
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = context.artworkColorFor(seed);
    final isRound = kind == ArtworkKind.artist;

    // A disc glyph on top of drawn vinyl grooves is the same idea said twice; the grooves already
    // are the record.
    final showGlyph = !(gradient && kind == ArtworkKind.album);

    final glyph = switch (kind) {
      ArtworkKind.track => AppIcons.music,
      ArtworkKind.album => AppIcons.disc,
      ArtworkKind.artist => AppIcons.person,
    };

    return ExcludeSemantics(
      // Decorative: the adjacent title and artist already carry the meaning.
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: isRound ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: isRound ? null : BorderRadius.circular(Radii.sm),
          color: gradient ? null : color,
          gradient: gradient
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [shade(color, 0.22), color, shade(color, -0.3)],
                )
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.hardEdge,
          children: [
            if (gradient) ..._decoration(kind, palette.glow, palette.accent),
            if (showGlyph)
              Icon(
                glyph,
                size: max(16, size * 0.36),
                color: palette.content.withValues(alpha: 0.82),
              ),
          ],
        ),
      ),
    );
  }

  /// Per-kind treatment, so the three tile types are told apart at a glance. Every dimension is a
  /// fraction of `size`, so one tile scales from a 56px grid cell to the full-screen player art.
  List<Widget> _decoration(ArtworkKind kind, Color glow, Color accent) {
    Widget circle(double fraction, {Color? fill, Color? border}) => Container(
      width: size * fraction,
      height: size * fraction,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: border != null ? Border.all(color: border) : null,
      ),
    );

    switch (kind) {
      case ArtworkKind.album:
        return [
          // Grooves. Three rings read as vinyl; more turns to moiré once scaled into a rail.
          for (final fraction in const [0.92, 0.72, 0.52])
            circle(fraction, border: glow.withValues(alpha: 0.16)),
          // Dark centre, then the label — the one spot of solid accent on the tile.
          circle(0.34, fill: Colors.black.withValues(alpha: 0.35)),
          circle(0.2, fill: accent),
          // Spindle hole.
          circle(0.06, fill: Colors.black.withValues(alpha: 0.55)),
        ];
      case ArtworkKind.artist:
        // Nested circles of rising opacity — close enough to a radial spotlight at these sizes.
        return [
          circle(0.96, fill: glow.withValues(alpha: 0.06)),
          circle(0.72, fill: glow.withValues(alpha: 0.09)),
          circle(0.48, fill: glow.withValues(alpha: 0.14)),
        ];
      case ArtworkKind.track:
        // Diagonal scan lines, overscaled so the ends clip past the corners.
        return [
          for (final (offset, alpha) in const [(-0.18, 0.22), (0.06, 0.12), (0.3, 0.07)])
            Positioned(
              left: -size * 0.3,
              top: size * (0.5 + offset),
              child: Transform.rotate(
                angle: -35 * pi / 180,
                child: Container(
                  width: size * 1.6,
                  height: max(1, size * 0.02),
                  color: glow.withValues(alpha: alpha),
                ),
              ),
            ),
        ];
    }
  }
}
