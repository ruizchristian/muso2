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
import '../ui/library/track_actions.dart';
import '../ui/library/track_row.dart';
import '../ui/widgets/app_icons.dart';
import '../ui/widgets/buttons.dart';
import '../ui/widgets/muso_text.dart';

/// Home is a starting point, not a showcase: one action, the newest songs, and a way into the
/// albums. Browsing everything else is the Library tab's job.
const _recentLimit = 5;
const _albumLimit = 10;

/// Smaller than the Library's album cards, so the rail reads as a footnote to the list above it.
const _albumSize = 112.0;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const LibraryGate(child: _HomeContent());
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    final library = context.library;
    final tracks = library.tracks;
    final engine = PlayerEngine.instance;

    final recent = ([
      ...tracks,
    ]..sort((a, b) => b.addedAt.compareTo(a.addedAt))).take(_recentLimit).toList();
    final albums = library.albums.take(_albumLimit).toList();

    // Tapping a recent song queues the whole recent run, so playback continues through what the
    // user was looking at rather than stopping after one song.
    void play(Track track) => engine.playTracks(recent, recent.indexOf(track));

    return ListView(
      padding: EdgeInsets.only(bottom: scrollPaddingOf(context)),
      children: [
        _Header(
          // Evaluated at build on purpose — it should reflect the time the screen opened.
          greeting: greeting(DateTime.now().hour),
          trackCount: tracks.length,
        ),
        ContentContainer(
          top: 8,
          child: MusoButton(
            label: 'Shuffle all',
            icon: AppIcons.shuffle,
            variant: ButtonVariant.secondary,
            block: true,
            disabled: tracks.isEmpty,
            onPressed: () => engine.shufflePlay(tracks),
          ),
        ),
        const ContentContainer(child: SectionHeader(title: 'Recently added')),
        ValueListenableBuilder<String?>(
          valueListenable: engine.currentTrackId,
          builder: (context, currentId, _) => Column(
            children: [
              for (final track in recent)
                TrackRow(
                  key: ValueKey(track.id),
                  track: track,
                  isCurrent: track.id == currentId,
                  isFavorite: library.favorites.contains(track.id),
                  onPress: play,
                  onToggleFavorite: library.toggleFavorite,
                  onShowActions: (track) => showTrackActions(context, track),
                ),
            ],
          ),
        ),
        if (albums.isNotEmpty) ...[
          const ContentContainer(child: SectionHeader(title: 'Albums')),
          SizedBox(
            height: _albumSize + 52,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              // Fixed-width cards, so the list can skip measurement entirely.
              itemExtent: _albumSize + 16,
              itemCount: albums.length,
              itemBuilder: (context, index) => AlbumCard(album: albums[index], size: _albumSize),
            ),
          ),
        ],
      ],
    );
  }
}

/// Plain masthead: greeting, song count, settings. No wash or rule — the list below is the
/// content, and the header only has to say where the user is.
class _Header extends StatelessWidget {
  const _Header({required this.greeting, required this.trackCount});

  final String greeting;
  final int trackCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: ContentContainer(
        top: 16,
        bottom: 16,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MusoText(greeting, variant: TextVariant.title, header: true),
                  const SizedBox(height: 2),
                  MusoText(
                    pluralize(trackCount, 'song'),
                    variant: TextVariant.caption,
                    tone: TextTone.muted,
                  ),
                ],
              ),
            ),
            MusoIconButton(
              icon: AppIcons.settings,
              semanticLabel: 'Settings',
              color: context.palette.content,
              onPressed: () => navigatorKey.currentState?.pushNamed(AppRoutes.settings),
            ),
          ],
        ),
      ),
    );
  }
}
