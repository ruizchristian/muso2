import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../media/media_backend.dart';
import '../state/library_controller.dart';
import '../state/theme_controller.dart';
import '../state/update_controller.dart';
import '../theme/layout.dart';
import '../theme/themes.dart';
import '../ui/common/states.dart';
import '../ui/common/update_banner.dart';
import '../ui/layout/layout_helpers.dart';
import '../ui/widgets/app_icons.dart';
import '../ui/widgets/buttons.dart';
import '../ui/widgets/muso_text.dart';
import '../ui/widgets/pressable_scale.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final library = context.library;
    final scanning = library.status == LibraryStatus.scanning;

    return Material(
      color: palette.base,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: Column(
          children: [
            ContentContainer(
              top: 8,
              child: Row(
                children: [
                  const Expanded(
                    child: MusoText('Settings', variant: TextVariant.title, header: true),
                  ),
                  MusoIconButton(
                    icon: AppIcons.close,
                    semanticLabel: 'Close settings',
                    color: palette.content,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(bottom: scrollPaddingOf(context)),
                children: [
                  const ContentContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader(title: 'Appearance'),
                        _ThemePicker(),
                      ],
                    ),
                  ),
                  ContentContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader(title: 'Library'),
                        _Card(
                          children: [
                            _Row(label: 'Songs', value: '${library.tracks.length}'),
                            _Row(label: 'Albums', value: '${library.albums.length}'),
                            _Row(label: 'Artists', value: '${library.artists.length}'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        MusoButton(
                          label: scanning
                              ? 'Scanning — ${pluralize(library.scanCount, 'song')}'
                              : 'Rescan device',
                          block: true,
                          loading: scanning,
                          onPressed: library.rescan,
                        ),
                        const SizedBox(height: 12),
                        const MusoText(
                          "Song, artist, and album names come from each file's name. Renaming "
                          'files to "Artist - Album - Title" gives the best results.',
                          variant: TextVariant.caption,
                          tone: TextTone.faint,
                        ),
                      ],
                    ),
                  ),
                  ContentContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader(title: 'Permissions'),
                        _Card(
                          children: [
                            _Row(
                              label: 'Media access',
                              value: library.permission == AudioPermissionState.granted
                                  ? 'Allowed'
                                  : 'Not allowed',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const MusoButton(
                          label: 'Open system settings',
                          variant: ButtonVariant.secondary,
                          block: true,
                          onPressed: openSystemSettings,
                        ),
                      ],
                    ),
                  ),
                  const ContentContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader(title: 'Updates'),
                        _UpdateSettings(),
                      ],
                    ),
                  ),
                  const ContentContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeader(title: 'About'),
                        MusoText(
                          'Muso plays audio files stored on this device. Apart from checking for '
                          'app updates, it makes no network requests, has no account, and is not '
                          'affiliated with Spotify.',
                          tone: TextTone.muted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Update status, plus a manual check. Everything here is read-only except the one button.
class _UpdateSettings extends StatelessWidget {
  const _UpdateSettings();

  @override
  Widget build(BuildContext context) {
    final updates = context.updates;
    final installed = updates.installed;
    final update = updates.update;
    final status = updates.status;

    if (status == UpdateStatus.unsupported) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Card(
            children: [_Row(label: 'Updates', value: 'Not available')],
          ),
          SizedBox(height: 8),
          MusoText(
            'In-app updates only work in release builds on Android.',
            variant: TextVariant.caption,
            tone: TextTone.faint,
          ),
        ],
      );
    }

    final lastChecked = updates.lastCheckedAt;
    final (label, primary) = switch (status) {
      UpdateStatus.downloading => (
        'Downloading — ${((updates.progress ?? 0) * 100).round()}%',
        true,
      ),
      UpdateStatus.ready => ('Install update', true),
      UpdateStatus.available => (
        'Download and install (${formatMegabytes(update!.sizeBytes)})',
        true,
      ),
      _ => ('Check for updates', false),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          children: [
            _Row(label: 'Installed', value: '${installed!.version} (${installed.build})'),
            if (update != null)
              _Row(label: 'Available', value: '${update.version} (${update.build})'),
            _Row(
              label: 'Last checked',
              value: lastChecked == null
                  ? 'Not yet'
                  : TimeOfDay.fromDateTime(lastChecked).format(context),
            ),
          ],
        ),
        if (updates.status == UpdateStatus.downloading) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: updates.progress,
              minHeight: 4,
              color: context.palette.accent,
              backgroundColor: context.palette.elevated,
            ),
          ),
        ],
        if (updates.error != null) ...[
          const SizedBox(height: 8),
          MusoText(updates.error!, variant: TextVariant.caption, tone: TextTone.danger),
        ],
        if (updates.notice != null) ...[
          const SizedBox(height: 8),
          MusoText(updates.notice!, variant: TextVariant.caption, tone: TextTone.muted),
        ],
        const SizedBox(height: 16),
        MusoButton(
          label: label,
          variant: primary ? ButtonVariant.primary : ButtonVariant.secondary,
          block: true,
          loading: status == UpdateStatus.checking,
          disabled: status == UpdateStatus.downloading,
          onPressed: primary ? () => startUpdate(context) : updates.checkNow,
        ),
        if (status == UpdateStatus.idle && lastChecked != null) ...[
          const SizedBox(height: 8),
          const MusoText('Muso is up to date.', variant: TextVariant.caption, tone: TextTone.faint),
        ],
      ],
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final current = context.musoTheme.id;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Column(
        children: [
          for (var i = 0; i < themeList.length; i += 1)
            _ThemeOption(option: themeList[i], selected: themeList[i].id == current, first: i == 0),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({required this.option, required this.selected, required this.first});

  final MusoTheme option;
  final bool selected;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: PressableScale(
        activeScale: 0.99,
        isButton: false,
        semanticLabel: '${option.label}. ${option.description}',
        excludeChildSemantics: true,
        onTap: () => context.read<ThemeController>().setTheme(option.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: palette.surface,
            border: first ? null : Border(top: BorderSide(color: palette.line)),
          ),
          child: Row(
            children: [
              // Swatches preview the palette directly, so the choice is not just a word.
              SizedBox(
                width: 24 * 3 - 8,
                height: 24,
                child: Stack(
                  children: [
                    for (final (index, swatch) in [
                      option.palette.base,
                      option.palette.elevated,
                      option.palette.accent,
                    ].indexed)
                      Positioned(
                        left: index * 20.0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: swatch,
                            shape: BoxShape.circle,
                            border: Border.all(color: palette.line),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MusoText(option.label, variant: TextVariant.label),
                    MusoText(
                      option.description,
                      variant: TextVariant.caption,
                      tone: TextTone.muted,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              if (selected) Icon(AppIcons.check, size: 18, color: palette.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(Radii.sm),
    ),
    child: Column(children: children),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        MusoText(label, tone: TextTone.muted),
        MusoText(value, variant: TextVariant.label),
      ],
    ),
  );
}
