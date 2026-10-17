import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Where releases are published. CI attaches the signed APK to every published release.
const updateRepository = 'ruizchristian/muso2';

/// The APK name CI gives every build: `Muso-<version>-<build>.apk`. The build number is the
/// Android versionCode, which is what decides whether Android treats the file as an upgrade.
final _apkName = RegExp(r'^Muso-([0-9A-Za-z.+\-]+)-(\d+)\.apk$');

/// A release newer than — or at least different from — the installed build.
class AvailableUpdate {
  const AvailableUpdate({
    required this.version,
    required this.build,
    required this.downloadUrl,
    required this.sizeBytes,
    this.sha256,
  });

  final String version;
  final int build;
  final Uri downloadUrl;
  final int sizeBytes;

  /// Lower-case hex digest GitHub computed on upload. Null for assets uploaded before GitHub
  /// started recording digests.
  final String? sha256;
}

/// Picks the installable APK out of a `releases/latest` response.
///
/// Returns null when the release has no APK yet — CI attaches it a few minutes after the release
/// is published, and until then there is simply nothing to offer.
AvailableUpdate? parseLatestRelease(Map<String, Object?> release) {
  if (release['draft'] == true || release['prerelease'] == true) return null;

  final assets = release['assets'];
  if (assets is! List) return null;

  AvailableUpdate? best;
  for (final asset in assets) {
    if (asset is! Map) continue;

    final match = _apkName.firstMatch('${asset['name']}');
    final url = Uri.tryParse('${asset['browser_download_url']}');
    final size = asset['size'];
    // An upload still in flight is listed with another state and an incomplete file.
    final state = asset['state'];
    if (match == null || url == null || url.scheme != 'https' || size is! int || size <= 0) {
      continue;
    }
    if (state != null && state != 'uploaded') continue;

    final digest = '${asset['digest']}';
    final candidate = AvailableUpdate(
      version: match.group(1)!,
      build: int.parse(match.group(2)!),
      downloadUrl: url,
      sizeBytes: size,
      sha256: digest.startsWith('sha256:') ? digest.substring(7).toLowerCase() : null,
    );
    if (best == null || candidate.build > best.build) best = candidate;
  }
  return best;
}

/// Thrown when a download finished but is not the file the release describes.
class CorruptDownloadException implements Exception {
  const CorruptDownloadException();
}

abstract interface class UpdateSource {
  /// The latest published release, or null when there is none with an APK.
  Future<AvailableUpdate?> latest();

  /// Streams the APK into `destination`, reporting bytes received so far, and verifies it.
  Future<void> download(
    AvailableUpdate update,
    File destination,
    void Function(int received) onProgress,
  );
}

class GitHubUpdateSource implements UpdateSource {
  const GitHubUpdateSource({this.repository = updateRepository});

  final String repository;

  static const _requestTimeout = Duration(seconds: 20);

  /// Gap between two chunks before a stalled download is abandoned. Generous, because a phone
  /// on a weak signal pauses for seconds at a time and recovers.
  static const _stallTimeout = Duration(seconds: 30);

  HttpClient _client() => HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..userAgent = 'Muso-updater';

  @override
  Future<AvailableUpdate?> latest() async {
    final client = _client();
    try {
      final request = await client
          .getUrl(Uri.https('api.github.com', '/repos/$repository/releases/latest'))
          .timeout(_requestTimeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response = await request.close().timeout(_requestTimeout);

      // 404 is GitHub's answer for "no published release yet", which is not an error.
      if (response.statusCode == HttpStatus.notFound) {
        await response.drain<void>();
        return null;
      }
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException('Release lookup failed (${response.statusCode})');
      }

      final body = await response.transform(utf8.decoder).join().timeout(_requestTimeout);
      final json = jsonDecode(body);
      return json is Map<String, Object?> ? parseLatestRelease(json) : null;
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> download(
    AvailableUpdate update,
    File destination,
    void Function(int received) onProgress,
  ) async {
    final client = _client();
    final sink = destination.openWrite();
    final hashOutput = _DigestSink();
    final hasher = sha256.startChunkedConversion(hashOutput);
    var received = 0;

    try {
      // The asset URL redirects to GitHub's CDN; HttpClient follows that on its own.
      final request = await client.getUrl(update.downloadUrl).timeout(_requestTimeout);
      final response = await request.close().timeout(_requestTimeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException('Download failed (${response.statusCode})');
      }

      await for (final chunk in response.timeout(_stallTimeout)) {
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        onProgress(received);
      }
    } finally {
      await sink.close();
      client.close(force: true);
    }

    hasher.close();
    // Android would refuse a truncated or tampered APK anyway, but only after the user has been
    // sent to the installer. Catching it here gives a clear "try again" instead.
    final expected = update.sha256;
    if (received != update.sizeBytes ||
        (expected != null && hashOutput.value.toString() != expected)) {
      throw const CorruptDownloadException();
    }
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
