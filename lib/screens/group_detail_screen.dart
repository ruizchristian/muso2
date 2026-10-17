import 'package:flutter/material.dart';

import '../core/format.dart';
import '../media/track.dart';
import '../player/engine.dart';
import '../state/library_controller.dart';
import '../state/theme_controller.dart';
import '../ui/common/states.dart';
import '../ui/library/track_list.dart';
import '../ui/widgets/app_icons.dart';
import '../ui/widgets/artwork.dart';
import '../ui/widgets/buttons.dart';
import '../ui/widgets/muso_text.dart';

enum GroupKind { album, artist }

const _heroHeight = 320.0;

/// Shared album/artist page: tinted hero, play + shuffle actions, then the track listing.
class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({super.key, required this.id, required this.kind});

  /// Route argument — validated in `onGenerateRoute`, but may still name a group that is gone.
  final String? id;
  final GroupKind kind;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final library = context.library;
    final groups = kind == GroupKind.album ? library.albums : library.artists;
    final group = id == null ? null : groups.where((group) => group.id == id).firstOrNull;
    final topInset = MediaQuery.paddingOf(context).top;

    final backButton = Padding(
      padding: EdgeInsets.only(top: topInset, left: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: MusoIconButton(
          icon: AppIcons.arrowLeft,
          semanticLabel: 'Go back',
          color: palette.content,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
    );

    if (group == null) {
      final isAlbum = kind == GroupKind.album;
      return Material(
        color: palette.base,
        child: Column(
          children: [
            backButton,
            Expanded(
              child: EmptyState(
                title: isAlbum ? 'Album not found' : 'Artist not found',
                message: 'This ${isAlbum ? 'album' : 'artist'} is no longer in your library.',
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: palette.base,
      child: Stack(
        children: [
          // Tinted to the album/artist so the header matches its artwork tile.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _heroHeight,
            child: ExcludeSemantics(child: ColoredBox(color: context.artworkColorFor(group.id))),
          ),
          Column(
            children: [
              backButton,
              Expanded(
                child: TrackList(
                  tracks: group.tracks,
                  header: _Header(group: group, kind: kind),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.group, required this.kind});

  final TrackGroup group;
  final GroupKind kind;

  @override
  Widget build(BuildContext context) {
    final totalMs = group.tracks.fold(0, (sum, track) => sum + track.durationMs);
    final engine = PlayerEngine.instance;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            child: Center(
              child: Artwork(
                seed: group.id,
                size: 200,
                // Artists have no cover of their own; a single album's art would misrepresent them.
                coverIds: kind == GroupKind.album ? coverIdsFor(group) : const [],
                kind: kind == GroupKind.album ? ArtworkKind.album : ArtworkKind.artist,
                gradient: true,
              ),
            ),
          ),
          MusoText(group.name, variant: TextVariant.display, maxLines: 2, header: true),
          const SizedBox(height: 8),
          MusoText(
            '${group.subtitle.isNotEmpty ? '${group.subtitle} · ' : ''}'
            '${pluralize(group.tracks.length, 'song')} · ${formatDuration(totalMs)}',
            tone: TextTone.muted,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              MusoButton(label: 'Play', onPressed: () => engine.playTracks(group.tracks)),
              const SizedBox(width: 12),
              MusoButton(
                label: 'Shuffle',
                variant: ButtonVariant.outline,
                onPressed: () => engine.shufflePlay(group.tracks),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
