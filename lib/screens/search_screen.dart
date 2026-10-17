import 'dart:async';

import 'package:flutter/material.dart';

import '../media/group.dart';
import '../state/library_controller.dart';
import '../ui/common/states.dart';
import '../ui/layout/layout_helpers.dart';
import '../ui/library/library_gate.dart';
import '../ui/library/track_list.dart';
import '../ui/widgets/app_icons.dart';
import '../ui/widgets/muso_text.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
    child: const LibraryGate(child: _SearchContent()),
  );
}

class _SearchContent extends StatefulWidget {
  const _SearchContent();

  @override
  State<_SearchContent> createState() => _SearchContentState();
}

class _SearchContentState extends State<_SearchContent> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Debounced so a 5,000-track filter does not run on every keystroke.
    _controller.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () {
        if (mounted && _query != _controller.text) setState(() => _query = _controller.text);
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracks = context.library.tracks;
    final trimmed = _query.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContentContainer(
          top: 8,
          bottom: 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MusoText('Search', variant: TextVariant.title, header: true),
              const SizedBox(height: 16),
              MusoSearchBar(controller: _controller),
            ],
          ),
        ),
        Expanded(
          child: trimmed.isNotEmpty
              ? TrackList(
                  tracks: searchTracks(tracks, trimmed),
                  empty: EmptyState(
                    icon: AppIcons.search,
                    title: 'No results',
                    message: 'Nothing in your library matches "$trimmed".',
                  ),
                )
              : const EmptyState(
                  icon: AppIcons.search,
                  title: 'Search your library',
                  message: 'Find any song, artist, or album stored on this device.',
                ),
        ),
      ],
    );
  }
}
