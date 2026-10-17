import 'package:flutter/material.dart';

import '../media/track.dart';
import '../state/library_controller.dart';
import '../state/theme_controller.dart';
import '../ui/common/states.dart';
import '../ui/layout/layout_helpers.dart';
import '../ui/widgets/app_icons.dart';
import '../ui/widgets/buttons.dart';
import '../ui/widgets/labeled_input.dart';
import '../ui/widgets/muso_text.dart';

class TrackEditScreen extends StatelessWidget {
  const TrackEditScreen({super.key, required this.id});

  final String? id;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final track = id == null
        ? null
        : context.library.tracks.where((track) => track.id == id).firstOrNull;

    return Material(
      color: palette.base,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ContentContainer(
              top: 8,
              child: Row(
                children: [
                  const Expanded(
                    child: MusoText('Edit details', variant: TextVariant.title, header: true),
                  ),
                  MusoIconButton(
                    icon: AppIcons.close,
                    semanticLabel: 'Close',
                    color: palette.content,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: track == null
                  ? const EmptyState(
                      title: 'Song not found',
                      message: 'It may have been removed from this device.',
                    )
                  : _TrackEditForm(track: track),
            ),
          ],
        ),
      ),
    );
  }
}

const _fields = [('title', 'Title'), ('artist', 'Artist'), ('album', 'Album')];

/// Edits a track's displayed metadata.
///
/// These edits are stored against the track id and layered over the scan result — the audio file
/// is never rewritten, because the media store exposes no tag-writing API at all. That is why the
/// form says "inside this app" rather than implying the file changes.
class _TrackEditForm extends StatefulWidget {
  const _TrackEditForm({required this.track});

  final Track track;

  @override
  State<_TrackEditForm> createState() => _TrackEditFormState();
}

class _TrackEditFormState extends State<_TrackEditForm> {
  late final _controllers = {
    'title': TextEditingController(text: widget.track.title),
    'artist': TextEditingController(text: widget.track.artist),
    'album': TextEditingController(text: widget.track.album),
  };
  final _errors = <String, String>{};
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    // Validated with the same rule that guards what gets persisted, so the two never disagree.
    final values = <String, String>{};
    final errors = <String, String>{};

    for (final (key, label) in _fields) {
      final value = TrackOverride.validField(_controllers[key]!.text);
      if (value == null) {
        errors[key] = _controllers[key]!.text.trim().isEmpty
            ? '$label is required.'
            : '$label must be ${TrackOverride.maxLength} characters or fewer.';
      } else {
        values[key] = value;
      }
    }

    if (errors.isNotEmpty) {
      setState(
        () => _errors
          ..clear()
          ..addAll(errors),
      );
      return;
    }

    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    await context.libraryActions.editTrack(
      widget.track.id,
      TrackOverride(title: values['title'], artist: values['artist'], album: values['album']),
    );
    navigator.pop();
  }

  Future<void> _reset() async {
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    await context.libraryActions.resetTrackMetadata(widget.track.id);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdited = context.library.hasOverride(widget.track.id);

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: 32 + MediaQuery.viewInsetsOf(context).bottom),
      children: [
        ContentContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              MusoText(widget.track.filename, variant: TextVariant.caption, tone: TextTone.muted),
              const SizedBox(height: 20),
              for (final (key, label) in _fields) ...[
                LabeledInput(
                  label: label,
                  controller: _controllers[key]!,
                  error: _errors[key],
                  maxLength: TrackOverride.maxLength,
                  textCapitalization: TextCapitalization.words,
                  // Clear this field's error as soon as it is touched: a stale message beside a
                  // field the user is actively fixing reads as the fix not working.
                  onChanged: (_) {
                    if (_errors.containsKey(key)) setState(() => _errors.remove(key));
                  },
                ),
                const SizedBox(height: 16),
              ],
              const MusoText(
                'Changes apply inside this app only. The audio file on your device is not '
                'modified, and its filename stays the same.',
                variant: TextVariant.caption,
                tone: TextTone.faint,
              ),
              const SizedBox(height: 24),
              MusoButton(label: 'Save', block: true, loading: _saving, onPressed: _save),
              if (isEdited) ...[
                const SizedBox(height: 12),
                MusoButton(
                  label: 'Reset to scanned values',
                  variant: ButtonVariant.secondary,
                  block: true,
                  disabled: _saving,
                  onPressed: _reset,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
