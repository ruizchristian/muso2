import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../media/media_backend.dart';
import '../../media/track.dart';
import '../../routes.dart';
import '../../state/library_controller.dart';
import '../../state/theme_controller.dart';
import '../../theme/layout.dart';
import '../widgets/app_icons.dart';
import '../widgets/muso_text.dart';

/// Row actions for a track: edit its metadata, or delete the file.
Future<void> showTrackActions(BuildContext context, Track track) async {
  final palette = context.read<ThemeController>().theme.palette;

  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: palette.elevated,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (sheetContext) {
      Widget action(String value, IconData icon, String label, {bool danger = false}) {
        final color = danger ? palette.danger : palette.content;
        return ListTile(
          leading: Icon(icon, color: color),
          title: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          onTap: () => Navigator.pop(sheetContext, value),
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MusoText(track.title, variant: TextVariant.heading, maxLines: 2),
                  MusoText(track.artist, tone: TextTone.muted, maxLines: 1),
                ],
              ),
            ),
            action('edit', AppIcons.edit, 'Edit details'),
            action('delete', AppIcons.delete, 'Delete from device', danger: true),
            action('cancel', AppIcons.close, 'Cancel'),
          ],
        ),
      );
    },
  );

  if (!context.mounted) return;

  switch (choice) {
    case 'edit':
      await navigatorKey.currentState?.pushNamed(AppRoutes.trackEdit, arguments: track.id);
    case 'delete':
      await _confirmDelete(context, track);
  }
}

Future<void> _confirmDelete(BuildContext context, Track track) async {
  final palette = context.read<ThemeController>().theme.palette;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: palette.elevated,
      title: Text('Delete this song?', style: TextStyle(color: palette.content)),
      // Names the track, and is explicit that this is not an app-level hide. Deleting someone's
      // only copy of a file because the wording was vague is not a recoverable mistake.
      content: Text(
        '"${track.title}" will be permanently deleted from this device. This cannot be undone.',
        style: TextStyle(color: palette.muted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('Cancel', style: TextStyle(color: palette.content)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('Delete', style: TextStyle(color: palette.danger)),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final result = await context.read<LibraryController>().deleteTrack(track.id);

  // `cancelled` covers backing out of Android's own confirmation dialog, which is a deliberate
  // choice and needs no follow-up message.
  if (result == DeleteResult.failed && context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: palette.elevated,
        title: Text('Could not delete', style: TextStyle(color: palette.content)),
        content: Text(
          'This song could not be removed right now.',
          style: TextStyle(color: palette.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('OK', style: TextStyle(color: palette.content)),
          ),
        ],
      ),
    );
  }
}
