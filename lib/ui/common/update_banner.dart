import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/format.dart';
import '../../player/engine.dart';
import '../../routes.dart';
import '../../state/theme_controller.dart';
import '../../state/update_controller.dart';
import '../widgets/app_icons.dart';
import '../widgets/buttons.dart';
import '../widgets/glass_panel.dart';
import '../widgets/muso_text.dart';
import '../widgets/pressable_scale.dart';

/// Downloads the update and opens the installer, asking first if music is playing.
///
/// Installing replaces the app, which stops playback mid-song. The queue and position are saved
/// and restored on the next launch, but a stop the user did not ask for is still hostile — so
/// while audio plays, the prompt says plainly what will happen.
Future<void> startUpdate(BuildContext context) {
  final updates = context.read<UpdateController>();
  final engine = PlayerEngine.instance;

  return updates.install(
    confirm: () async {
      if (engine.playback.value.isPlaying) {
        // The banner sits above the navigator, so dialogs go through the navigator's context.
        final dialogContext = navigatorKey.currentContext;
        if (dialogContext == null) return false;
        final palette = dialogContext.read<ThemeController>().theme.palette;

        final confirmed = await showDialog<bool>(
          context: dialogContext,
          builder: (context) => AlertDialog(
            backgroundColor: palette.elevated,
            title: Text('Install the update now?', style: TextStyle(color: palette.content)),
            content: Text(
              'Playback will stop while Android installs the new version. Your queue and '
              'position are saved and restored when Muso reopens.',
              style: TextStyle(color: palette.muted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Not now', style: TextStyle(color: palette.content)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Install', style: TextStyle(color: palette.accent)),
              ),
            ],
          ),
        );
        if (confirmed != true) return false;
      }

      engine.pause();
      await engine.flushPersist();
      return true;
    },
  );
}

/// Tells the user an update is waiting, without taking the screen.
///
/// A dialog would be the obvious thing and the wrong one: it would appear mid-song and offer a
/// button that stops the music. A dismissible banner lets the user finish what they were doing
/// and come back to it.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final updates = context.updates;
    final visible = updates.showBanner;
    final top = MediaQuery.paddingOf(context).top + 8;
    final duration = Duration(milliseconds: reducedMotion(context) ? 0 : 220);

    return Positioned(
      left: 12,
      right: 12,
      top: top,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, -0.4),
          duration: duration,
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: duration,
            child: visible ? const _BannerBody() : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _BannerBody extends StatelessWidget {
  const _BannerBody();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final updates = context.updates;
    final update = updates.update!;

    final (title, detail) = switch (updates.status) {
      UpdateStatus.downloading => (
        'Downloading update',
        '${((updates.progress ?? 0) * 100).round()}% of ${formatMegabytes(update.sizeBytes)}',
      ),
      UpdateStatus.ready => ('Update ready', 'Muso ${update.version} is downloaded.'),
      _ => ('Update available', 'Muso ${update.version} · ${formatMegabytes(update.sizeBytes)}'),
    };

    // Announced in passing rather than by moving focus: the user is mid-task, and an update is
    // never urgent enough to interrupt what they were reading.
    return Semantics(
      liveRegion: true,
      child: GlassPanel(
        tone: GlassTone.neon,
        glow: true,
        intensity: 45,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              Icon(AppIcons.update, size: 20, color: palette.glow),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MusoText(title, variant: TextVariant.label),
                    const SizedBox(height: 2),
                    MusoText(
                      detail,
                      variant: TextVariant.caption,
                      tone: TextTone.muted,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              MusoButton(
                label: 'Install',
                size: ControlSize.sm,
                loading: updates.isBusy,
                onPressed: () => startUpdate(context),
              ),
              MusoIconButton(
                icon: AppIcons.close,
                size: ControlSize.sm,
                semanticLabel: 'Dismiss update notice',
                color: palette.muted,
                onPressed: context.read<UpdateController>().dismiss,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
