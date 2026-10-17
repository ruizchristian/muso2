import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../update/update_platform.dart';
import '../update/update_source.dart';

enum UpdateStatus { unsupported, idle, checking, available, downloading, ready, error }

/// How long to wait before another foreground check. Someone switching apps every few seconds
/// should not generate a request each time.
const _checkInterval = Duration(minutes: 15);

/// Finds new releases on GitHub, downloads the APK on request and hands it to Android's
/// installer.
///
/// One controller rather than a check in each place that shows update state, so the banner and
/// Settings share a single checker — two would double every request and could disagree.
///
/// Nothing is downloaded until the user asks: an APK is tens of megabytes, and that is not a
/// cost to run up on someone's mobile data in the background.
class UpdateController extends ChangeNotifier {
  UpdateController({UpdateSource? source, UpdatePlatform? platform, DateTime Function()? clock})
    : _source = source ?? const GitHubUpdateSource(),
      _platform = platform ?? const AndroidUpdatePlatform(),
      _clock = clock ?? DateTime.now;

  final UpdateSource _source;
  final UpdatePlatform _platform;
  final DateTime Function() _clock;

  AppLifecycleListener? _lifecycle;
  bool _disposed = false;
  bool _checking = false;

  UpdateStatus _status = UpdateStatus.checking;
  InstalledVersion? _installed;
  AvailableUpdate? _update;
  File? _downloaded;
  double? _progress;
  String? _error;
  String? _notice;
  DateTime? _lastCheckedAt;

  /// Which build was dismissed, rather than a dismissed flag. Dismissing means "not this one,
  /// not now", so a newer release has to surface again on its own.
  int? _dismissedBuild;

  /// Set while the user is away granting "Install unknown apps", so returning to the app picks
  /// the install back up instead of making them find the button again.
  bool _installOnResume = false;

  UpdateStatus get status => _status;
  InstalledVersion? get installed => _installed;
  AvailableUpdate? get update => _update;

  /// 0-1 while downloading, otherwise null.
  double? get progress => _progress;

  /// Generic, user-safe text. Never the raw exception.
  String? get error => _error;

  /// Guidance that is not an error, such as what to do on the permission screen.
  String? get notice => _notice;
  DateTime? get lastCheckedAt => _lastCheckedAt;

  bool get isBusy => _status == UpdateStatus.checking || _status == UpdateStatus.downloading;

  /// Whether the banner should show. Checking and errors stay in Settings, where the user asked
  /// the question; surfacing them over content would be noise.
  bool get showBanner =>
      _update != null &&
      _update!.build != _dismissedBuild &&
      (_status == UpdateStatus.available ||
          _status == UpdateStatus.downloading ||
          _status == UpdateStatus.ready);

  Future<void> init() async {
    try {
      _installed = await _platform.installed();
    } catch (_) {
      _installed = null;
    }

    if (_installed == null) {
      _set(UpdateStatus.unsupported);
      return;
    }

    // Re-check when the app returns to the foreground. No interval timer: a backgrounded app has
    // no reason to poll, and this is the moment the user is about to look at it anyway.
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_onResume()));

    await _removeStaleDownloads();
    await checkNow();
  }

  /// Looks for a newer release. `force: false` is the foreground re-check, which is throttled.
  Future<void> checkNow({bool force = true}) async {
    if (_status == UpdateStatus.unsupported || _checking || _status == UpdateStatus.downloading) {
      return;
    }
    final last = _lastCheckedAt;
    if (!force && last != null && _clock().difference(last) < _checkInterval) return;

    _checking = true;
    _error = null;
    // With an update already on offer the re-check runs quietly, so the banner and the install
    // button do not blink away while it is in flight.
    if (_update == null) _set(UpdateStatus.checking);

    try {
      final latest = await _source.latest();
      _lastCheckedAt = _clock();

      if (latest != null && latest.build > _installed!.build) {
        // A different build than the one already downloaded makes that file worthless.
        if (_update?.build != latest.build) _downloaded = null;
        _update = latest;
        _downloaded ??= await _existingDownload(latest);
        _set(_downloaded != null ? UpdateStatus.ready : UpdateStatus.available);
      } else {
        _update = null;
        _downloaded = null;
        _set(UpdateStatus.idle);
      }
    } catch (_) {
      _error = 'Could not check for updates right now.';
      // A failed re-check does not make an update found earlier disappear.
      _set(
        _update == null
            ? UpdateStatus.error
            : (_downloaded != null ? UpdateStatus.ready : UpdateStatus.available),
      );
    } finally {
      _checking = false;
    }
  }

  /// Downloads the update if needed, then opens Android's installer.
  ///
  /// `confirm` runs after the download and before the installer, which replaces the app and
  /// stops playback — that is the moment the user has to agree to, not the start of a download.
  Future<void> install({Future<bool> Function()? confirm}) async {
    final update = _update;
    if (update == null || isBusy) return;
    _error = null;
    _notice = null;

    if (_downloaded == null) {
      try {
        _downloaded = await _download(update);
      } catch (_) {
        _progress = null;
        _error = 'Could not download the update. Check your connection and try again.';
        _set(UpdateStatus.available);
        return;
      }
    }

    _progress = null;
    _set(UpdateStatus.ready);

    if (confirm != null && !await confirm()) return;
    await _launchInstaller();
  }

  void dismiss() {
    _dismissedBuild = _update?.build;
    notifyListeners();
  }

  Future<void> _onResume() async {
    if (_installOnResume) {
      _installOnResume = false;
      if (_downloaded != null && await _canInstall()) {
        await _launchInstaller();
        return;
      }
    }
    await checkNow(force: false);
  }

  Future<void> _launchInstaller() async {
    final apk = _downloaded;
    if (apk == null) return;

    if (!await _canInstall()) {
      _installOnResume = true;
      _notice = 'Allow Muso to install apps, then come back to finish the update.';
      notifyListeners();
      await _platform.openInstallSettings();
      return;
    }

    _notice = null;
    final opened = await _platform.install(apk);
    if (!opened) _error = 'Could not open the installer.';
    notifyListeners();
  }

  Future<bool> _canInstall() async {
    try {
      return await _platform.canInstall();
    } catch (_) {
      return false;
    }
  }

  Future<Directory> _updatesDirectory() async =>
      Directory('${(await _platform.cacheDirectory()).path}/updates');

  File _fileFor(Directory directory, AvailableUpdate update) =>
      File('${directory.path}/Muso-${update.build}.apk');

  Future<File> _download(AvailableUpdate update) async {
    final directory = await _updatesDirectory();
    await directory.create(recursive: true);

    final target = _fileFor(directory, update);
    // Downloaded under a temporary name, so a half-written file is never mistaken for a
    // finished one after the app is killed mid-download.
    final partial = File('${target.path}.part');

    _progress = 0;
    _set(UpdateStatus.downloading);

    var lastNotified = 0.0;
    try {
      await _source.download(update, partial, (received) {
        final value = (received / update.sizeBytes).clamp(0.0, 1.0);
        _progress = value;
        // One rebuild per percent is plenty for a progress bar.
        if (value - lastNotified >= 0.01) {
          lastNotified = value;
          notifyListeners();
        }
      });
      return await partial.rename(target.path);
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }

  /// A finished download from an earlier session, for example when the user backed out of the
  /// installer or Android restarted the app after granting the install permission.
  Future<File?> _existingDownload(AvailableUpdate update) async {
    try {
      final file = _fileFor(await _updatesDirectory(), update);
      if (await file.exists() && await file.length() == update.sizeBytes) return file;
    } catch (_) {
      // An unreadable cache just means downloading again.
    }
    return null;
  }

  /// Deletes partial downloads and APKs for builds that are already installed — after a
  /// successful update the file that installed it is dead weight.
  Future<void> _removeStaleDownloads() async {
    try {
      final directory = await _updatesDirectory();
      if (!await directory.exists()) return;

      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        final build = RegExp(r'^Muso-(\d+)\.apk$').firstMatch(entity.uri.pathSegments.last);
        if (build == null || int.parse(build.group(1)!) <= _installed!.build) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Cleanup is best-effort; a leftover file costs space, not correctness.
    }
  }

  void _set(UpdateStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _lifecycle?.dispose();
    super.dispose();
  }
}

extension UpdateContext on BuildContext {
  UpdateController get updates => watch<UpdateController>();
}
