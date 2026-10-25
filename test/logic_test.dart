import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:music/core/alphabet.dart';
import 'package:music/core/format.dart';
import 'package:music/core/search_history.dart';
import 'package:music/media/group.dart';
import 'package:music/media/overrides.dart';
import 'package:music/media/parse_filename.dart';
import 'package:music/media/sort.dart';
import 'package:music/media/track.dart';
import 'package:music/player/shuffle.dart';

Track track(
  String id, {
  String title = 'Title',
  String artist = 'Artist',
  String album = 'Album',
  int addedAt = 0,
}) => Track(
  id: id,
  title: title,
  artist: artist,
  album: album,
  durationMs: 180000,
  filename: '$id.mp3',
  addedAt: addedAt,
);

void main() {
  group('parseFilename', () {
    test('reads Artist - Album - Title', () {
      final parsed = parseFilename('Daft Punk - Discovery - One More Time.mp3');
      expect(parsed.artist, 'Daft Punk');
      expect(parsed.album, 'Discovery');
      expect(parsed.title, 'One More Time');
    });

    test('keeps trailing separators in the title', () {
      expect(parseFilename('A - B - C - D.mp3').title, 'C - D');
    });

    test('reads Artist - Title', () {
      final parsed = parseFilename('Adele - Hello.m4a');
      expect(parsed.artist, 'Adele');
      expect(parsed.album, unknownAlbum);
      expect(parsed.title, 'Hello');
    });

    test('strips a leading track number and tidies underscores', () {
      final parsed = parseFilename('01 - My_Song__Name.flac');
      expect(parsed.title, 'My Song Name');
      expect(parsed.artist, unknownArtist);
    });

    test('falls back to the raw name when stripping leaves nothing', () {
      expect(parseFilename('07.mp3').title, '07');
    });
  });

  group('grouping', () {
    final tracks = [
      track('1', artist: 'Zed', album: 'Greatest Hits'),
      track('2', artist: 'Abba', album: 'Greatest Hits'),
      track('3', artist: 'abba', album: 'Arrival'),
    ];

    test('albums stay separate per artist and sort by name', () {
      final albums = groupByAlbum(tracks);
      expect(albums.map((a) => a.name), ['Arrival', 'Greatest Hits', 'Greatest Hits']);
    });

    test('artists merge case-insensitively and carry a song count', () {
      final artists = groupByArtist(tracks);
      expect(artists, hasLength(2));
      expect(artists.first.subtitle, '2 songs');
      expect(artists.last.subtitle, '1 song');
    });

    test('search matches title, artist and album', () {
      expect(searchTracks(tracks, 'arriv').map((t) => t.id), ['3']);
      expect(searchTracks(tracks, '  ABBA ').map((t) => t.id), ['2', '3']);
      expect(searchTracks(tracks, '   '), isEmpty);
    });
  });

  group('overrides', () {
    final scanned = track('1', title: 'Old', artist: 'Someone');

    test('apply returns the same list when nothing is overridden', () {
      final tracks = [scanned];
      expect(identical(applyOverrides(tracks, {}), tracks), isTrue);
      expect(
        identical(applyOverrides(tracks, {'other': const TrackOverride(title: 'X')}), tracks),
        isTrue,
      );
    });

    test('apply layers edits over the scan', () {
      final result = applyOverrides([scanned], {'1': const TrackOverride(title: 'New')});
      expect(result.single.title, 'New');
      expect(result.single.artist, 'Someone');
    });

    test('merge drops fields equal to the scanned value', () {
      expect(mergeOverride(scanned, null, const TrackOverride(title: 'Old')), isNull);

      final merged = mergeOverride(
        scanned,
        const TrackOverride(artist: 'Edited'),
        const TrackOverride(title: ' New '),
      );
      expect(merged, const TrackOverride(title: 'New', artist: 'Edited'));
    });

    test('override parsing rejects blank and over-long fields', () {
      expect(TrackOverride.tryParse({'title': 'Fine'}), const TrackOverride(title: 'Fine'));
      expect(TrackOverride.tryParse({'title': '   '}), isNull);
      expect(TrackOverride.tryParse({'title': 'x' * 201}), isNull);
    });
  });

  group('alphabet', () {
    test('buckets fold accents and send non-letters to #', () {
      expect(bucketFor('Ángel'), 'A');
      expect(bucketFor('zebra'), 'Z');
      expect(bucketFor('99 Problems'), '#');
      expect(bucketFor('   '), '#');
    });

    test('index maps each bucket to its first row', () {
      final index = buildLetterIndex(['1st', 'Alpha', 'Apple', 'Beta'], (s) => s);
      expect(index, {'#': 0, 'A': 1, 'B': 3});
    });
  });

  group('format', () {
    test('durations', () {
      expect(formatDuration(0), '0:00');
      expect(formatDuration(-5), '0:00');
      expect(formatDuration(65000), '1:05');
      expect(formatDuration(3723000), '1:02:03');
    });

    test('counts and plurals', () {
      expect(formatCount(5000), '5,000');
      expect(formatCount(1234567), '1,234,567');
      expect(formatCount(12), '12');
      expect(pluralize(1, 'song'), '1 song');
      expect(pluralize(3, 'song'), '3 songs');
    });

    test('greeting', () {
      expect(greeting(8), 'Good morning');
      expect(greeting(13), 'Good afternoon');
      expect(greeting(21), 'Good evening');
    });
  });

  group('sort', () {
    final tracks = [
      track('a', title: 'beta', addedAt: 1),
      track('b', title: 'Alpha', addedAt: 3),
      track('c', title: 'gamma', addedAt: 2),
    ];

    List<String> ids(SortKey key, [Map<String, int> counts = const {}]) =>
        ([...tracks]..sort(compareBySortKey(key, counts))).map((t) => t.id).toList();

    test('title is case-insensitive', () => expect(ids(SortKey.title), ['b', 'a', 'c']));
    test('time added is newest first', () => expect(ids(SortKey.addedAt), ['b', 'c', 'a']));
    test('play count ties fall back to title', () {
      expect(ids(SortKey.playCount, {'c': 5}), ['c', 'b', 'a']);
    });
  });

  group('shuffle', () {
    test('keeps the current item first and loses nothing', () {
      final items = List.generate(20, (i) => i);
      final shuffled = shuffleKeepingCurrent(items, 7, random: Random(1));

      expect(shuffled.first, 7);
      expect(shuffled.toSet(), items.toSet());
      expect(shuffled, hasLength(items.length));
    });
  });

  group('track json', () {
    test('round-trips', () {
      final original = track('1', title: 'T', addedAt: 42);
      final parsed = Track.tryParse(original.toJson())!;
      expect(parsed.toJson(), original.toJson());
    });

    test('rejects malformed rows', () {
      expect(Track.tryParse({'id': '1'}), isNull);
      expect(Track.tryParse({...track('1').toJson(), 'durationMs': -1}), isNull);
      expect(Track.tryParse('nope'), isNull);
    });
  });

  group('search history', () {
    test('puts the newest search first and trims it', () {
      expect(addToSearchHistory(['queen'], '  abba '), ['abba', 'queen']);
    });

    test('a repeat moves up instead of duplicating, ignoring case', () {
      expect(addToSearchHistory(['abba', 'Queen'], 'queen'), ['queen', 'abba']);
    });

    test('ignores blank queries', () {
      final history = ['abba'];
      expect(addToSearchHistory(history, '   '), same(history));
    });

    test('keeps only the most recent', () {
      final full = [for (var i = 0; i < searchHistoryLimit; i += 1) 'q$i'];
      final next = addToSearchHistory(full, 'new');
      expect(next, hasLength(searchHistoryLimit));
      expect(next.first, 'new');
      expect(next, isNot(contains('q${searchHistoryLimit - 1}')));
    });
  });
}
