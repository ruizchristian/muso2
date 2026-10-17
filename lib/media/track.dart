/// Domain model for a single on-device audio file.
///
/// `uri` is optional: resolving a media-store asset's playable URI is a native round-trip per
/// asset, so it is looked up lazily at playback time (see `media_backend.dart`) unless the scan
/// already supplied one.
class Track {
  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.filename,
    required this.addedAt,
    this.uri,
  });

  /// Media-store asset id.
  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String filename;

  /// UNIX ms; `0` when the media store does not record one.
  final int addedAt;
  final String? uri;

  Track copyWith({String? title, String? artist, String? album}) => Track(
    id: id,
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    durationMs: durationMs,
    filename: filename,
    addedAt: addedAt,
    uri: uri,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'durationMs': durationMs,
    'filename': filename,
    'addedAt': addedAt,
    if (uri != null) 'uri': uri,
  };

  /// Validating parse. Returns null for any malformed row — persisted data is external input, and
  /// one bad entry must degrade to "skip it", never to a crash on startup.
  static Track? tryParse(Object? json) {
    if (json is! Map) return null;

    final id = _nonEmpty(json['id']);
    final title = _nonEmpty(json['title']);
    final artist = _nonEmpty(json['artist']);
    final album = _nonEmpty(json['album']);
    final filename = _nonEmpty(json['filename']);
    final durationMs = _nonNegative(json['durationMs']);
    final addedAt = _nonNegative(json['addedAt']);
    final uri = json['uri'];

    if (id == null ||
        title == null ||
        artist == null ||
        album == null ||
        filename == null ||
        durationMs == null ||
        addedAt == null) {
      return null;
    }
    if (uri != null && _nonEmpty(uri) == null) return null;

    return Track(
      id: id,
      title: title,
      artist: artist,
      album: album,
      durationMs: durationMs,
      filename: filename,
      addedAt: addedAt,
      uri: uri as String?,
    );
  }
}

String? _nonEmpty(Object? value) => value is String && value.isNotEmpty ? value : null;

int? _nonNegative(Object? value) {
  if (value is! num || !value.isFinite || value < 0) return null;
  return value.round();
}

enum RepeatMode { off, all, one }

enum SortKey { title, addedAt, playCount }

/// User-supplied replacements for the values parsed out of a filename.
///
/// The media store exposes no tag-writing API, so an edit can never reach the audio file itself.
/// Edits are stored keyed by track id and layered over the scan result on read. Every field is
/// optional: an override only carries what the user actually changed.
class TrackOverride {
  const TrackOverride({this.title, this.artist, this.album});

  final String? title;
  final String? artist;
  final String? album;

  static const maxLength = 200;

  bool get isEmpty => title == null && artist == null && album == null;

  String? operator [](String field) => switch (field) {
    'title' => title,
    'artist' => artist,
    'album' => album,
    _ => null,
  };

  Map<String, String> toJson() => {'title': ?title, 'artist': ?artist, 'album': ?album};

  /// Trimmed, non-empty and length-capped — the same rule guards form input and persisted data.
  static String? validField(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > maxLength) return null;
    return trimmed;
  }

  static TrackOverride? tryParse(Object? json) {
    if (json is! Map) return null;

    String? field(String key) {
      final raw = json[key];
      if (raw == null) return null;
      return validField(raw) ?? (throw const FormatException());
    }

    try {
      return TrackOverride(title: field('title'), artist: field('artist'), album: field('album'));
    } on FormatException {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is TrackOverride &&
      other.title == title &&
      other.artist == artist &&
      other.album == album;

  @override
  int get hashCode => Object.hash(title, artist, album);
}

/// Derived, never persisted: an album or artist bucket built by grouping tracks in memory.
class TrackGroup {
  TrackGroup({required this.id, required this.name, required this.subtitle, required this.tracks});

  final String id;
  final String name;
  String subtitle;
  final List<Track> tracks;
}
