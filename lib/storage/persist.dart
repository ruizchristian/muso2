import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Schema-validated key-value wrapper.
///
/// Nothing stored here is sensitive (a track listing and playback position), so plain shared
/// preferences are the right store. Reads are always validated: persisted data is external input,
/// and a shape change between app versions must degrade to "no cached value" rather than crashing
/// on startup.
abstract final class StorageKeys {
  static const library = 'my-music:library:v1';
  static const playback = 'my-music:playback:v1';
  static const favorites = 'my-music:favorites:v1';
  static const playCounts = 'my-music:play-counts:v1';
  static const theme = 'my-music:theme:v1';
  static const overrides = 'my-music:overrides:v1';
}

SharedPreferencesAsync? _prefs;
SharedPreferencesAsync get _store => _prefs ??= SharedPreferencesAsync();

/// Reads and validates a versioned JSON document. `parse` returns null for a bad shape, in which
/// case the stale or corrupt value is dropped so the next read starts clean.
Future<T?> readPersisted<T>(String key, T? Function(Map<String, Object?> json) parse) async {
  try {
    final raw = await _store.getString(key);
    if (raw == null || raw.isEmpty) return null;

    final decoded = jsonDecode(raw);
    final value = decoded is Map<String, Object?> && decoded['version'] == 1
        ? parse(decoded)
        : null;

    if (value == null) await _store.remove(key);
    return value;
  } catch (_) {
    return null;
  }
}

Future<void> writePersisted(String key, Map<String, Object?> value) async {
  try {
    await _store.setString(key, jsonEncode({'version': 1, ...value}));
  } catch (_) {
    // A full disk must not take playback down; the value is a cache, not a source of truth.
  }
}

Future<void> removePersisted(String key) async {
  try {
    await _store.remove(key);
  } catch (_) {
    // Ignore — see above.
  }
}
