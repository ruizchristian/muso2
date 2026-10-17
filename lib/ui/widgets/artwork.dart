import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/color.dart';
import '../../media/cover_art.dart';
import '../../media/track.dart';
import '../../state/theme_controller.dart';
import '../../theme/layout.dart';
import 'app_icons.dart';
import 'pressable_scale.dart';

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

/// How many of a group's tracks are tried for its cover. Albums are usually tagged consistently,
/// so the first few settle it; trying every track would make one tile cost a whole album's reads.
const _groupCoverAttempts = 3;

/// Track ids to look for a group's cover in, in order.
List<String> coverIdsFor(TrackGroup group) => [
  for (final track in group.tracks.take(_groupCoverAttempts)) track.id,
];

/// What the tile stands for. Drives the placeholder's shape and glyph.
enum ArtworkKind { track, album, artist }

/// Artwork tile: the cover embedded in the audio file when there is one, otherwise a flat tile in
/// a colour derived from `seed` — the same album always gets the same colour, which keeps grids
/// scannable even without covers.
class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.seed,
    required this.size,
    this.coverIds = const [],
    this.kind = ArtworkKind.track,
    this.gradient = false,
  });

  final String seed;
  final double size;

  /// Tracks whose embedded cover to show, first match wins. Empty keeps the placeholder.
  final List<String> coverIds;
  final ArtworkKind kind;

  /// A soft diagonal shade on the placeholder, for large tiles where a flat block looks unfinished.
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = context.artworkColorFor(seed);
    final isRound = kind == ArtworkKind.artist;

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
                  colors: [shade(color, 0.12), shade(color, -0.12)],
                )
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Icon(
                glyph,
                size: max(16, size * 0.34),
                color: palette.content.withValues(alpha: 0.7),
              ),
            ),
            if (coverIds.isNotEmpty)
              _Cover(
                // Keyed by source, so a recycled row never shows the previous track's cover while
                // the new one loads.
                key: ValueKey(coverIds.join(',')),
                ids: coverIds,
                pixels: size * MediaQuery.devicePixelRatioOf(context),
              ),
          ],
        ),
      ),
    );
  }
}

/// The embedded cover, faded in over the placeholder once it has loaded. Stays invisible when the
/// file has none.
class _Cover extends StatefulWidget {
  const _Cover({super.key, required this.ids, required this.pixels});

  final List<String> ids;
  final double pixels;

  @override
  State<_Cover> createState() => _CoverState();
}

class _CoverState extends State<_Cover> {
  late Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = CoverArt.load(widget.ids, widget.pixels);
  }

  @override
  void didUpdateWidget(_Cover oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A bigger tile for the same source (the player art growing) needs a sharper decode.
    if (widget.pixels > oldWidget.pixels) _bytes = CoverArt.load(widget.ids, widget.pixels);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return const SizedBox.shrink();

        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          // Decode at display size, not the file's size: a list of full-resolution covers would
          // hold tens of megabytes of bitmaps for 44px rows.
          cacheWidth: widget.pixels.ceil(),
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, synchronous) {
            if (synchronous) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: Duration(milliseconds: reducedMotion(context) ? 0 : 180),
              child: child,
            );
          },
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        );
      },
    );
  }
}
