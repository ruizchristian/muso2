import 'package:flutter/material.dart';

import '../core/format.dart';
import '../media/track.dart';
import '../player/engine.dart';
import '../routes.dart';
import '../state/library_controller.dart';
import '../state/theme_controller.dart';
import '../ui/common/states.dart';
import '../ui/layout/layout_helpers.dart';
import '../ui/library/library_gate.dart';
import '../ui/library/library_widgets.dart';
import '../ui/widgets/app_icons.dart';
import '../ui/widgets/artwork.dart';
import '../ui/widgets/buttons.dart';
import '../ui/widgets/glass_panel.dart';
import '../ui/widgets/muso_text.dart';
import '../ui/widgets/pressable_scale.dart';

/// One oversized feature card, then four half-width tiles. Six identical squares gave the eye no
/// entry point and no sense of what was newest.
const _featureCount = 1;
const _quickTileCount = 4;
const _railLimit = 10;
const _artistRankLimit = 5;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Edge-to-edge so the hero's gradient runs under the status bar; the hero pays the inset itself.
  @override
  Widget build(BuildContext context) => const LibraryGate(child: _HomeContent());
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    final library = context.library;
    final tracks = library.tracks;

    final recentlyAdded = ([...tracks]..sort((a, b) => b.addedAt.compareTo(a.addedAt)))
        .take(_featureCount + _quickTileCount)
        .toList();
    final feature = recentlyAdded.firstOrNull;
    final quickTiles = recentlyAdded.skip(_featureCount).toList();

    final recentAlbums = library.albums.take(_railLimit).toList();
    final topArtists = ([
      ...library.artists,
    ]..sort((a, b) => b.tracks.length.compareTo(a.tracks.length))).take(_artistRankLimit).toList();

    // Tapping any recent track makes the whole recent run the queue, so playback continues through
    // what the user was looking at rather than stopping after one song.
    void play(Track track) =>
        PlayerEngine.instance.playTracks(recentlyAdded, recentlyAdded.indexOf(track));

    return ListView(
      padding: EdgeInsets.only(bottom: scrollPaddingOf(context)),
      children: [
        _HomeHero(
          // Evaluated at build on purpose — it should reflect the time the screen opened.
          greeting: greeting(DateTime.now().hour),
          trackCount: tracks.length,
        ),
        ContentContainer(
          child: Column(
            children: [
              if (feature != null)
                _FeatureCard(track: feature, queueLength: recentlyAdded.length, onPlay: play),
              const SizedBox(height: 12),
              for (var row = 0; row < quickTiles.length; row += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _QuickTile(track: quickTiles[row], onPlay: play),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: row + 1 < quickTiles.length
                            ? _QuickTile(track: quickTiles[row + 1], onPlay: play)
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const ContentContainer(child: SectionHeader(title: 'Your albums', rule: true)),
        SizedBox(
          height: albumCardWidth + 52,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            // Fixed-width cards, so the list can skip measurement entirely.
            itemExtent: albumCardWidth + 16,
            itemCount: recentAlbums.length,
            itemBuilder: (context, index) => AlbumCard(album: recentAlbums[index]),
          ),
        ),
        ContentContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(
                title: 'Top artists',
                subtitle: 'Ranked by how much of your library they fill',
                rule: true,
              ),
              _ArtistRankList(artists: topArtists),
            ],
          ),
        ),
      ],
    );
  }
}

/// Full-bleed masthead. The wash runs under the status bar rather than starting below it: a
/// gradient that stops at the inset line reads as a banner stuck to the top of the page.
class _HomeHero extends StatelessWidget {
  const _HomeHero({required this.greeting, required this.trackCount});

  final String greeting;
  final int trackCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        // Both stops well under half opacity — at full strength the wash competes with the
        // artwork tiles directly beneath it.
        gradient: LinearGradient(
          begin: gradientPoint(0.1, 0),
          end: gradientPoint(0.9, 1),
          colors: [
            palette.accent.withValues(alpha: 0.32),
            palette.glow.withValues(alpha: 0.1),
            Colors.transparent,
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: ContentContainer(
          top: 12,
          bottom: 24,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MusoText(
                      '${formatCount(trackCount)} tracks · on this device',
                      variant: TextVariant.overline,
                      tone: TextTone.accent,
                    ),
                    const SizedBox(height: 4),
                    MusoText(greeting, variant: TextVariant.display, header: true),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              MusoIconButton(
                icon: AppIcons.settings,
                semanticLabel: 'Settings',
                color: palette.content,
                onPressed: () => navigatorKey.currentState?.pushNamed(AppRoutes.settings),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The single largest thing on the home screen: the most recently added track.
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.track, required this.queueLength, required this.onPlay});

  final Track track;
  final int queueLength;
  final ValueChanged<Track> onPlay;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return PressableScale(
      activeScale: 0.98,
      semanticLabel: 'Play ${track.title} by ${track.artist}',
      semanticHint: 'First of $queueLength recently added tracks',
      excludeChildSemantics: true,
      onTap: () => onPlay(track),
      child: GlassPanel(
        tone: GlassTone.neon,
        glow: true,
        intensity: 50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Artwork(seed: trackSeed(track.album, track.artist), size: 88, gradient: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MusoText(
                      'Latest addition',
                      variant: TextVariant.overline,
                      tone: TextTone.accent,
                    ),
                    const SizedBox(height: 4),
                    MusoText(track.title, variant: TextVariant.heading, maxLines: 2),
                    const SizedBox(height: 4),
                    MusoText(
                      track.artist,
                      variant: TextVariant.caption,
                      tone: TextTone.muted,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Solid accent against the glow-rimmed glass: the one unambiguous CTA on the screen.
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: palette.accent, shape: BoxShape.circle),
                child: Icon(AppIcons.play, size: 26, color: palette.onAccent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Half-width glass tile. Four of these sit under the feature card.
class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.track, required this.onPlay});

  final Track track;
  final ValueChanged<Track> onPlay;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      semanticLabel: 'Play ${track.title} by ${track.artist}',
      excludeChildSemantics: true,
      onTap: () => onPlay(track),
      child: GlassPanel(
        radius: 8,
        intensity: 30,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              Artwork(seed: trackSeed(track.album, track.artist), size: 56, gradient: true),
              const SizedBox(width: 8),
              Expanded(
                child: MusoText(
                  track.title,
                  variant: TextVariant.caption,
                  fontWeight: FontWeight.w700,
                  maxLines: 2,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top artists as a ranked chart inside one pane. The rank number is the point: it makes the sort
/// visible instead of implied.
class _ArtistRankList extends StatelessWidget {
  const _ArtistRankList({required this.artists});

  final List<TrackGroup> artists;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GlassPanel(
      intensity: 30,
      child: Column(
        children: [
          for (var i = 0; i < artists.length; i += 1)
            PressableScale(
              activeScale: 0.99,
              semanticLabel:
                  'Number ${i + 1}, ${artists[i].name}, ${artists[i].tracks.length} tracks',
              excludeChildSemantics: true,
              onTap: () =>
                  navigatorKey.currentState?.pushNamed(AppRoutes.artist, arguments: artists[i].id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: i == artists.length - 1
                    ? null
                    : BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                      ),
                child: Row(
                  children: [
                    // Fixed width so double digits don't shunt every avatar sideways.
                    SizedBox(
                      width: 24,
                      child: MusoText(
                        '${i + 1}',
                        variant: TextVariant.label,
                        tone: TextTone.faint,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Artwork(seed: artists[i].id, size: 40, kind: ArtworkKind.artist),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MusoText(artists[i].name, variant: TextVariant.label, maxLines: 1),
                          const SizedBox(height: 2),
                          MusoText(
                            pluralize(artists[i].tracks.length, 'track'),
                            variant: TextVariant.caption,
                            tone: TextTone.muted,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    Icon(AppIcons.chevronRight, size: 18, color: palette.faint),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
