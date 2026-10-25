import 'dart:async';

import 'package:flutter/material.dart';

import '../core/search_history.dart';
import '../media/group.dart';
import '../state/library_controller.dart';
import '../state/theme_controller.dart';
import '../storage/library_cache.dart';
import '../ui/common/states.dart';
import '../ui/layout/layout_helpers.dart';
import '../ui/library/library_gate.dart';
import '../ui/library/track_list.dart';
import '../ui/widgets/app_icons.dart';
import '../ui/widgets/buttons.dart';
import '../ui/widgets/muso_text.dart';
import '../ui/widgets/pressable_scale.dart';

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

  /// Recent searches, newest first.
  List<String> _history = const [];

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
    unawaited(_loadHistory());
  }

  Future<void> _loadHistory() async {
    final saved = await readSearchHistory();
    if (!mounted) return;
    // Anything searched while the read was in flight stays on top of what was saved.
    setState(() => _history = _history.reversed.fold(saved, addToSearchHistory));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _setHistory(List<String> history) {
    setState(() => _history = history);
    unawaited(writeSearchHistory(history));
  }

  /// A search counts once the user acts on it (the keyboard's search key or playing a result),
  /// not on every half-typed query the debounce lets through.
  void _remember(String query) {
    final next = addToSearchHistory(_history, query);
    if (next != _history) _setHistory(next);
  }

  void _forget(String query) => _setHistory(_history.where((entry) => entry != query).toList());

  void _searchFor(String query) {
    FocusManager.instance.primaryFocus?.unfocus();
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    // Show results now rather than after the debounce.
    _debounce?.cancel();
    setState(() => _query = query);
    _remember(query);
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
              MusoSearchBar(controller: _controller, onSubmitted: _remember),
            ],
          ),
        ),
        Expanded(
          child: trimmed.isNotEmpty
              ? TrackList(
                  tracks: searchTracks(tracks, trimmed),
                  onPlay: (_) => _remember(trimmed),
                  empty: EmptyState(
                    icon: AppIcons.search,
                    title: 'No results',
                    message: 'Nothing in your library matches "$trimmed".',
                  ),
                )
              : _history.isNotEmpty
              ? _RecentSearches(
                  history: _history,
                  onSelect: _searchFor,
                  onRemove: _forget,
                  onClear: () => _setHistory(const []),
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

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({
    required this.history,
    required this.onSelect,
    required this.onRemove,
    required this.onClear,
  });

  final List<String> history;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: scrollPaddingOf(context)),
      children: [
        ContentContainer(
          top: 8,
          child: Row(
            children: [
              const Expanded(
                child: MusoText('Recent searches', variant: TextVariant.heading, header: true),
              ),
              MusoButton(
                label: 'Clear',
                variant: ButtonVariant.ghost,
                size: ControlSize.sm,
                onPressed: onClear,
              ),
            ],
          ),
        ),
        for (final query in history)
          ContentContainer(
            child: PressableScale(
              semanticLabel: 'Search for $query',
              onTap: () => onSelect(query),
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    Icon(AppIcons.history, size: 20, color: palette.faint),
                    const SizedBox(width: 12),
                    Expanded(child: MusoText(query, maxLines: 1)),
                    MusoIconButton(
                      icon: AppIcons.close,
                      size: ControlSize.sm,
                      semanticLabel: 'Remove $query from recent searches',
                      onPressed: () => onRemove(query),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
