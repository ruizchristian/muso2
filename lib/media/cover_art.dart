import 'dart:io';

import 'package:flutter/services.dart';

/// Cover art embedded in the audio files, read through the media store (`MainActivity.kt`).
///
/// Results — including "no cover" — are cached per request, so a list scrolling back over rows
/// it has already shown never goes back to the platform.
abstract final class CoverArt {
  static const _channel = MethodChannel('muso/artwork');

  /// Requests are rounded up to one of these, so a 44px row and a 48px tile share one decode.
  static const _buckets = [128, 256, 512, 1024];

  /// Small rows dominate, at roughly 10 KB each; a few full-size player covers fit alongside.
  static const _maxEntries = 200;

  // Map literals keep insertion order, which is what makes the LRU below work.
  static final _cache = <String, Future<Uint8List?>>{};

  /// The first embedded cover among `trackIds`, at least `pixels` on its longer edge, or null.
  static Future<Uint8List?> load(List<String> trackIds, double pixels) {
    if (trackIds.isEmpty || !Platform.isAndroid) return Future.value();

    final size = _buckets.firstWhere((bucket) => bucket >= pixels, orElse: () => _buckets.last);
    final key = '$size|${trackIds.join(',')}';

    final cached = _cache.remove(key);
    if (cached != null) {
      // Re-inserted so the map's order doubles as least-recently-used.
      _cache[key] = cached;
      return cached;
    }

    final request = _fetch(trackIds, size);
    _cache[key] = request;
    if (_cache.length > _maxEntries) _cache.remove(_cache.keys.first);
    return request;
  }

  static Future<Uint8List?> _fetch(List<String> trackIds, int size) async {
    try {
      return await _channel.invokeMethod<Uint8List>('cover', {'ids': trackIds, 'size': size});
    } catch (_) {
      // No platform side (tests) or an unreadable file: the placeholder stays.
      return null;
    }
  }

  /// Forgets everything, e.g. after a rescan in which files may have gained or lost covers.
  static void clear() => _cache.clear();
}
