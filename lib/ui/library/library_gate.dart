import 'package:flutter/material.dart';

import '../../media/media_backend.dart';
import '../../state/library_controller.dart';
import '../common/states.dart';
import '../widgets/app_icons.dart';

/// Renders permission, scanning, error, and empty states for the on-device library, and only
/// shows `child` once there are tracks to display. Every library-backed screen wraps in one of
/// these so the states stay identical across tabs.
class LibraryGate extends StatelessWidget {
  const LibraryGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final library = context.library;

    // Checked before the permission branches: when the platform has no media store, permission
    // never resolves past `undetermined`, and prompting for access would be a dead end.
    if (library.status == LibraryStatus.error) {
      return ErrorView(
        message: library.error ?? 'Could not read your music.',
        onRetry: library.rescan,
      );
    }

    switch (library.permission) {
      case AudioPermissionState.blocked:
        return const EmptyState(
          icon: AppIcons.settings,
          title: 'Music access is turned off',
          message:
              'Muso needs permission to read the audio files on this device. You can turn it '
              'back on in Settings.',
          actionLabel: 'Open Settings',
          onAction: openSystemSettings,
        );
      case AudioPermissionState.undetermined || AudioPermissionState.denied:
        return EmptyState(
          title: 'Find your music',
          message:
              'Muso plays the audio files already stored on this device. Nothing is uploaded and '
              'no account is needed — it just needs permission to read them.',
          actionLabel: 'Allow access',
          onAction: library.requestPermission,
        );
      case AudioPermissionState.granted:
        break;
    }

    final isLoading =
        library.status == LibraryStatus.checking || library.status == LibraryStatus.scanning;

    // Only block on the scan when there is nothing cached to show underneath it.
    if (isLoading && library.tracks.isEmpty) {
      return LoadingView(
        message: library.scanCount > 0 ? 'Found ${library.scanCount} songs…' : 'Looking for music…',
      );
    }

    if (library.tracks.isEmpty) {
      return EmptyState(
        title: 'No music found',
        message: 'There are no audio files on this device yet. Add some music and scan again.',
        actionLabel: 'Scan again',
        onAction: library.rescan,
      );
    }

    return child;
  }
}
