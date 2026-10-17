import 'package:flutter_test/flutter_test.dart';
import 'package:music/media/track.dart';
import 'package:music/player/audio_output.dart';
import 'package:music/player/engine.dart';
import 'package:music/player/play_counts.dart';
import 'package:music/storage/library_cache.dart';

/// Records what the engine asked of the player, and lets a test push status updates back.
class FakeOutput extends AudioOutput {
  final loaded = <String>[];
  final missing = <String>{};
  bool playing = false;
  int? lastSeek;

  @override
  Future<void> init() async {}

  @override
  Future<bool> load(String uri, Track track) async {
    loaded.add(track.id);
    return !missing.contains(track.id);
  }

  @override
  void play() => playing = true;

  @override
  void pause() => playing = false;

  @override
  Future<void> seek(int positionMs) async => lastSeek = positionMs;

  @override
  Future<void> dispose() async {}

  void push({required int positionMs, bool finished = false}) => onStatus?.call(
    OutputStatus(
      playing: playing && !finished,
      buffering: false,
      positionMs: positionMs,
      durationMs: 180000,
      didJustFinish: finished,
    ),
  );
}

Track t(String id) => Track(
  id: id,
  title: 'Song $id',
  artist: 'Artist',
  album: 'Album',
  durationMs: 180000,
  filename: '$id.mp3',
  addedAt: 0,
);

void main() {
  late FakeOutput output;
  late PlayerEngine engine;
  PersistedPlayback? saved;
  final tracks = [t('a'), t('b'), t('c'), t('d')];

  setUp(() {
    output = FakeOutput();
    saved = null;
    engine = PlayerEngine(
      createOutput: () => output,
      resolveUri: (track) async => 'content://media/${track.id}',
      readPlayback: () async => saved,
      writePlayback: (playback) async => saved = playback,
      playCounts: PlayCounts.instance,
    );
  });

  PlaybackState state() => engine.playback.value;

  test('playTracks starts at the tapped track and autoplays', () async {
    await engine.playTracks(tracks, 2);

    expect(state().currentTrack!.id, 'c');
    expect(output.loaded, ['c']);
    expect(output.playing, isTrue);
    expect(engine.currentTrackId.value, 'c');
  });

  test('a shuffled queue leads with the tapped track', () async {
    engine.setShuffle(true);
    await engine.playTracks(tracks, 3);

    expect(state().currentIndex, 0);
    expect(state().queue.first.id, 'd');
    expect(state().queue.map((t) => t.id).toSet(), {'a', 'b', 'c', 'd'});
  });

  test('turning shuffle off keeps the current track and restores source order', () async {
    await engine.playTracks(tracks, 1);
    engine.setShuffle(true);
    expect(state().currentTrack!.id, 'b');

    engine.setShuffle(false);
    expect(state().queue.map((t) => t.id), ['a', 'b', 'c', 'd']);
    expect(state().currentIndex, 1);
  });

  test('the end of the queue stops when repeat is off, wraps when it is all', () async {
    await engine.playTracks(tracks, 3);
    output.push(positionMs: 180000, finished: true);
    await pumpEventQueue();

    expect(state().currentTrack!.id, 'd');
    expect(output.playing, isFalse);

    engine.cycleRepeat(); // all
    await engine.next();
    expect(state().currentTrack!.id, 'a');
  });

  test('repeat one restarts the same track when it finishes', () async {
    await engine.playTracks(tracks, 1);
    engine
      ..cycleRepeat()
      ..cycleRepeat(); // one
    expect(state().repeat, RepeatMode.one);

    output.push(positionMs: 180000, finished: true);
    await pumpEventQueue();

    expect(state().currentTrack!.id, 'b');
    expect(output.lastSeek, 0);
  });

  test('previous restarts past three seconds, otherwise steps back', () async {
    await engine.playTracks(tracks, 2);

    output.push(positionMs: 5000);
    await engine.previous();
    expect(state().currentTrack!.id, 'c');
    expect(output.lastSeek, 0);

    output.push(positionMs: 1000);
    await engine.previous();
    expect(state().currentTrack!.id, 'b');
  });

  test('a missing file surfaces an error instead of playing', () async {
    output.missing.add('a');
    await engine.playTracks(tracks, 0);

    expect(state().error, contains('no longer on this device'));
    expect(state().isPlaying, isFalse);
  });

  test('a play counts once, after the threshold', () async {
    await engine.playTracks(tracks, 0);
    final before = PlayCounts.instance.value['a'] ?? 0;

    output.push(positionMs: PlayCounts.thresholdMs - 1);
    output.push(positionMs: PlayCounts.thresholdMs);
    output.push(positionMs: PlayCounts.thresholdMs + 500);

    expect(PlayCounts.instance.value['a'], before + 1);
  });

  group('removeTrackFromQueue', () {
    test('removing an earlier track keeps the same one playing', () async {
      await engine.playTracks(tracks, 2);
      await engine.removeTrackFromQueue('a');

      expect(state().currentTrack!.id, 'c');
      expect(state().currentIndex, 1);
      expect(state().sourceQueue.map((t) => t.id), ['b', 'c', 'd']);
    });

    test('removing the current track moves to the next, keeping play state', () async {
      await engine.playTracks(tracks, 1);
      await engine.removeTrackFromQueue('b');

      expect(state().currentTrack!.id, 'c');
      expect(output.loaded.last, 'c');
      expect(output.playing, isTrue);
    });

    test('removing the last queued track tears the session down but keeps preferences', () async {
      engine.cycleRepeat();
      await engine.playTracks([t('only')]);
      await engine.removeTrackFromQueue('only');

      expect(state().currentTrack, isNull);
      expect(state().repeat, RepeatMode.all);
      expect(output.playing, isFalse);
    });
  });

  test('restorePlayback rehydrates against the library, paused, at the saved position', () async {
    saved = const PersistedPlayback(
      queue: ['gone', 'b', 'c'],
      currentIndex: 1,
      positionMs: 42000,
      shuffle: false,
      repeat: RepeatMode.all,
    );

    await engine.restorePlayback(tracks);

    // "gone" drops out, so saved index 1 now points at "c".
    expect(state().queue.map((t) => t.id), ['b', 'c']);
    expect(state().currentTrack!.id, 'c');
    expect(state().repeat, RepeatMode.all);
    expect(output.playing, isFalse);
    expect(output.lastSeek, 42000);
  });
}
