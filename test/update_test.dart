import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:music/state/update_controller.dart';
import 'package:music/update/update_platform.dart';
import 'package:music/update/update_source.dart';

Map<String, Object?> _asset(String name, {int size = 1000, String state = 'uploaded'}) => {
  'name': name,
  'size': size,
  'state': state,
  'browser_download_url': 'https://github.com/o/r/releases/download/v1/$name',
  'digest': 'sha256:ABCDEF',
};

class _FakeSource implements UpdateSource {
  AvailableUpdate? latestRelease;
  Object? checkError;
  Object? downloadError;
  int downloads = 0;

  @override
  Future<AvailableUpdate?> latest() async {
    if (checkError != null) throw checkError!;
    return latestRelease;
  }

  @override
  Future<void> download(
    AvailableUpdate update,
    File destination,
    void Function(int received) onProgress,
  ) async {
    downloads += 1;
    if (downloadError != null) throw downloadError!;
    await destination.writeAsBytes(List.filled(update.sizeBytes, 7));
    onProgress(update.sizeBytes);
  }
}

class _FakePlatform implements UpdatePlatform {
  _FakePlatform(this.cache);

  final Directory cache;
  InstalledVersion? version = const InstalledVersion(version: '1.0.0', build: 100);
  bool allowed = true;
  int settingsOpened = 0;
  final installs = <String>[];

  @override
  Future<InstalledVersion?> installed() async => version;

  @override
  Future<Directory> cacheDirectory() async => cache;

  @override
  Future<bool> canInstall() async => allowed;

  @override
  Future<void> openInstallSettings() async => settingsOpened += 1;

  @override
  Future<bool> install(File apk) async {
    installs.add(apk.path);
    return true;
  }
}

AvailableUpdate _update(int build, {int size = 64}) => AvailableUpdate(
  version: '1.0.1',
  build: build,
  downloadUrl: Uri.parse('https://example.com/Muso-1.0.1-$build.apk'),
  sizeBytes: size,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseLatestRelease', () {
    test('reads version, build, size and digest from the APK asset', () {
      final update = parseLatestRelease({
        'assets': [_asset('notes.txt'), _asset('Muso-1.2.0-26101812.apk', size: 5000)],
      })!;

      expect(update.version, '1.2.0');
      expect(update.build, 26101812);
      expect(update.sizeBytes, 5000);
      expect(update.sha256, 'abcdef');
      expect(update.downloadUrl.path, endsWith('Muso-1.2.0-26101812.apk'));
    });

    test('is null while CI has not attached the APK yet', () {
      expect(parseLatestRelease({'assets': <Object?>[]}), isNull);
      expect(
        parseLatestRelease({
          'assets': [_asset('Muso-1.2.0-26101812.apk', state: 'starter')],
        }),
        isNull,
      );
    });

    test('ignores drafts, prereleases and non-https links', () {
      final assets = [_asset('Muso-1.0.0-1.apk')];
      expect(parseLatestRelease({'draft': true, 'assets': assets}), isNull);
      expect(parseLatestRelease({'prerelease': true, 'assets': assets}), isNull);
      expect(
        parseLatestRelease({
          'assets': [
            {..._asset('Muso-1.0.0-1.apk'), 'browser_download_url': 'http://x/Muso-1.0.0-1.apk'},
          ],
        }),
        isNull,
      );
    });

    test('prefers the highest build when several APKs are attached', () {
      final update = parseLatestRelease({
        'assets': [_asset('Muso-1.0.0-5.apk'), _asset('Muso-1.0.0-9.apk')],
      });
      expect(update!.build, 9);
    });
  });

  group('UpdateController', () {
    late Directory cache;
    late _FakeSource source;
    late _FakePlatform platform;

    setUp(() async {
      cache = await Directory.systemTemp.createTemp('muso-update-test');
      source = _FakeSource();
      platform = _FakePlatform(cache);
    });

    tearDown(() async {
      if (await cache.exists()) await cache.delete(recursive: true);
    });

    UpdateController controller() => UpdateController(source: source, platform: platform);

    test('is unsupported where the platform cannot update (debug builds)', () async {
      platform.version = null;
      final updates = controller();
      await updates.init();
      expect(updates.status, UpdateStatus.unsupported);
      updates.dispose();
    });

    test('reports up to date when the release is not newer', () async {
      source.latestRelease = _update(100);
      final updates = controller();
      await updates.init();
      expect(updates.status, UpdateStatus.idle);
      expect(updates.showBanner, isFalse);
      updates.dispose();
    });

    test('offers a newer build, downloads it and opens the installer', () async {
      source.latestRelease = _update(200);
      final updates = controller();
      await updates.init();
      expect(updates.status, UpdateStatus.available);
      expect(updates.showBanner, isTrue);

      await updates.install();
      expect(updates.status, UpdateStatus.ready);
      expect(platform.installs.single, endsWith('Muso-200.apk'));
      expect(File(platform.installs.single).lengthSync(), 64);
      updates.dispose();
    });

    test('does not open the installer when the user declines', () async {
      source.latestRelease = _update(200);
      final updates = controller();
      await updates.init();
      await updates.install(confirm: () async => false);
      expect(updates.status, UpdateStatus.ready);
      expect(platform.installs, isEmpty);
      updates.dispose();
    });

    test('reuses a finished download from an earlier session', () async {
      source.latestRelease = _update(200);
      await Directory('${cache.path}/updates').create();
      await File('${cache.path}/updates/Muso-200.apk').writeAsBytes(List.filled(64, 1));

      final updates = controller();
      await updates.init();
      expect(updates.status, UpdateStatus.ready);
      await updates.install();
      expect(source.downloads, 0);
      expect(platform.installs, hasLength(1));
      updates.dispose();
    });

    test('sends the user to the permission screen when installs are not allowed', () async {
      source.latestRelease = _update(200);
      platform.allowed = false;
      final updates = controller();
      await updates.init();
      await updates.install();
      expect(platform.settingsOpened, 1);
      expect(platform.installs, isEmpty);
      expect(updates.notice, isNotNull);
      updates.dispose();
    });

    test('a failed download leaves the update on offer with a generic message', () async {
      source.latestRelease = _update(200);
      source.downloadError = const SocketException('offline');
      final updates = controller();
      await updates.init();
      await updates.install();
      expect(updates.status, UpdateStatus.available);
      expect(updates.error, isNot(contains('offline')));
      expect(Directory('${cache.path}/updates').listSync(), isEmpty);
      updates.dispose();
    });

    test('a failed check is an error, but does not hide an update found earlier', () async {
      source.checkError = const SocketException('offline');
      final updates = controller();
      await updates.init();
      expect(updates.status, UpdateStatus.error);

      source
        ..checkError = null
        ..latestRelease = _update(200);
      await updates.checkNow();
      source.checkError = const SocketException('offline');
      await updates.checkNow();
      expect(updates.status, UpdateStatus.available);
      expect(updates.error, isNotNull);
      updates.dispose();
    });

    test('dismissing hides this build only', () async {
      source.latestRelease = _update(200);
      final updates = controller();
      await updates.init();
      updates.dismiss();
      expect(updates.showBanner, isFalse);

      source.latestRelease = _update(300);
      await updates.checkNow();
      expect(updates.showBanner, isTrue);
      updates.dispose();
    });

    test('cleans out APKs for builds that are already installed', () async {
      final dir = await Directory('${cache.path}/updates').create();
      await File('${dir.path}/Muso-100.apk').writeAsString('old');
      await File('${dir.path}/Muso-300.apk.part').writeAsString('partial');
      await File('${dir.path}/Muso-300.apk').writeAsString('newer');

      final updates = controller();
      await updates.init();
      final names = dir.listSync().map((e) => e.uri.pathSegments.last).toList();
      expect(names, ['Muso-300.apk']);
      updates.dispose();
    });
  });
}
