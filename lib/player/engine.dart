import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../media/media_backend.dart' as media;
import '../media/track.dart';
import '../storage/library_cache.dart';
import 'audio_output.dart';
import 'play_counts.dart';
import 'shuffle.dart';

/// Pressing "previous" past this point restarts the track instead of stepping back.
const _restartThresholdMs = 3000;

@immutable
class PlaybackState {
  const PlaybackState({
    this.queue = const [],
    this.sourceQueue = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.isBuffering = false,
    this.shuffle = false,
    this.repeat = RepeatMode.off,
    this.error,
  });

  /// Play order currently in effect (already shuffled when `shuffle` is on).
  final List<Track> queue;

  /// Insertion order, kept so shuffle can be turned back off.
  final List<Track> sourceQueue;
  final int currentIndex;
  final bool isPlaying;
  final bool isBuffering;
  final bool shuffle;
  final RepeatMode repeat;

  /// Set when a queued file has gone missing since the last scan.
  final String? error;

  Track? get currentTrack =>
      currentIndex >= 0 && currentIndex < queue.length ? queue[currentIndex] : null;

  PlaybackState copyWith({
    List<Track>? queue,
    List<Track>? sourceQueue,
    int? currentIndex,
    bool? isPlaying,
    bool? isBuffering,
    bool? shuffle,
    RepeatMode? repeat,
    String? Function()? error,
  }) => PlaybackState(
    queue: queue ?? this.queue,
    sourceQueue: sourceQueue ?? this.sourceQueue,
    currentIndex: currentIndex ?? this.currentIndex,
    isPlaying: isPlaying ?? this.isPlaying,
    isBuffering: isBuffering ?? this.isBuffering,
    shuffle: shuffle ?? this.shuffle,
    repeat: repeat ?? this.repeat,
    error: error != null ? error() : this.error,
  );
}

@immutable
class ProgressState {
  const ProgressState({this.positionMs = 0, this.durationMs = 0});

  final int positionMs;
  final int durationMs;

  @override
  bool operator ==(Object other) =>
      other is ProgressState && other.positionMs == positionMs && other.durationMs == durationMs;

  @override
  int get hashCode => Object.hash(positionMs, durationMs);
}

/// The queue and transport, independent of any widget.
///
/// Playback state changes at two very different rates: queue/track changes are rare, playback
/// position ticks twice a second. They live in separate notifiers so a scrubber rebuild never
/// drags the whole screen with it — and `currentTrackId` is split out again because a long list
/// only cares which row is highlighted, not about play/pause.
class PlayerEngine implements TransportCommands {
  PlayerEngine({
    AudioOutput Function()? createOutput,
    Future<String?> Function(Track track)? resolveUri,
    Future<PersistedPlayback?> Function()? readPlayback,
    Future<void> Function(PersistedPlayback playback)? writePlayback,
    PlayCounts? playCounts,
  }) : _createOutput = createOutput ?? JustAudioOutput.new,
       _resolveUri = resolveUri ?? media.resolveTrackUri,
       _readPlayback = readPlayback ?? readCachedPlayback,
       _writePlayback = writePlayback ?? writeCachedPlayback,
       _playCounts = playCounts ?? PlayCounts.instance {
    playback.addListener(() {
      final id = playback.value.currentTrack?.id;
      if (currentTrackId.value != id) currentTrackId.value = id;
    });
  }

  static final instance = PlayerEngine();

  final AudioOutput Function() _createOutput;
  final Future<String?> Function(Track track) _resolveUri;
  final Future<PersistedPlayback?> Function() _readPlayback;
  final Future<void> Function(PersistedPlayback playback) _writePlayback;
  final PlayCounts _playCounts;

  final playback = ValueNotifier(const PlaybackState());
  final progress = ValueNotifier(const ProgressState());

  /// Id of the playing track. Changes only when the track actually changes.
  final currentTrackId = ValueNotifier<String?>(null);

  AudioOutput? _output;

  /// Reset on every track load so one listen counts once, however often status ticks.
  bool _countedCurrentPlay = false;

  /// Guards against an out-of-order load resolving after a newer one.
  int _loadToken = 0;
  Timer? _persistTimer;

  PlaybackState get _state => playback.value;

  AudioOutput get output => _output ??= _createOutput()
    ..onStatus = _onStatus
    ..commands = this;

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(seconds: 1), () {
      _persistTimer = null;
      unawaited(_persistNow());
    });
  }

  Future<void> _persistNow() {
    final state = _state;
    return _writePlayback(
      PersistedPlayback(
        queue: [for (final track in state.queue) track.id],
        currentIndex: state.currentIndex < 0 ? 0 : state.currentIndex,
        positionMs: progress.value.positionMs,
        shuffle: state.shuffle,
        repeat: state.repeat,
      ),
    );
  }

  /// Writes the queue and position immediately instead of after the debounce. Used before
  /// something is about to kill the process — an app update — so the next launch resumes exactly
  /// where the user was.
  Future<void> flushPersist() {
    _persistTimer?.cancel();
    _persistTimer = null;
    return _persistNow();
  }

  void _onStatus(OutputStatus status) {
    progress.value = ProgressState(
      positionMs: status.positionMs < 0 ? 0 : status.positionMs,
      durationMs: status.durationMs > 0
          ? status.durationMs
          : (_state.currentTrack?.durationMs ?? 0),
    );

    // Count a play once the listener has actually stayed with the track, and only once per load.
    if (!_countedCurrentPlay && status.playing && status.positionMs >= PlayCounts.thresholdMs) {
      final track = _state.currentTrack;
      if (track != null) {
        _countedCurrentPlay = true;
        _playCounts.record(track.id);
      }
    }

    if (_state.isPlaying != status.playing || _state.isBuffering != status.buffering) {
      playback.value = _state.copyWith(isPlaying: status.playing, isBuffering: status.buffering);
    }

    if (status.didJustFinish) unawaited(_handleTrackFinished());
  }

  /// Configures the audio session once at startup: keep playing in the background, take exclusive
  /// focus, and pause when headphones or a Bluetooth output disconnect.
  Future<void> initAudioSession() => output.init();

  Future<void> _loadTrack(int index, {required bool autoPlay}) async {
    final track = index >= 0 && index < _state.queue.length ? _state.queue[index] : null;
    if (track == null) return;

    final token = ++_loadToken;
    _countedCurrentPlay = false;
    playback.value = _state.copyWith(currentIndex: index, error: () => null, isBuffering: true);
    progress.value = ProgressState(durationMs: track.durationMs);

    void markMissing() {
      playback.value = _state.copyWith(
        isBuffering: false,
        isPlaying: false,
        error: () => '"${track.title}" is no longer on this device.',
      );
    }

    final uri = await _resolveUri(track);
    // A newer load started while this one was resolving — discard this result.
    if (token != _loadToken) return;

    if (uri == null) {
      markMissing();
      return;
    }

    final loaded = await output.load(uri, track);
    if (token != _loadToken) return;

    if (!loaded) {
      markMissing();
      return;
    }

    if (autoPlay) output.play();
    _schedulePersist();
  }

  /// Starts a fresh queue at `startIndex`, honouring the current shuffle setting.
  Future<void> playTracks(List<Track> tracks, [int startIndex = 0]) async {
    if (tracks.isEmpty) return;

    final safeIndex = startIndex.clamp(0, tracks.length - 1);
    final queue = _state.shuffle ? shuffleKeepingCurrent(tracks, safeIndex) : tracks;

    playback.value = _state.copyWith(
      sourceQueue: tracks,
      queue: queue,
      // A shuffled queue always leads with the track the user tapped.
      currentIndex: _state.shuffle ? 0 : safeIndex,
      error: () => null,
    );

    await _loadTrack(_state.currentIndex, autoPlay: true);
  }

  /// Starts a queue with shuffle forced on — the "Shuffle play" entry point.
  Future<void> shufflePlay(List<Track> tracks) async {
    if (tracks.isEmpty) return;

    final start = Random().nextInt(tracks.length);
    playback.value = _state.copyWith(shuffle: true);
    await playTracks(tracks, start);
  }

  void togglePlayPause() {
    if (_state.currentIndex < 0) return;

    if (_state.isPlaying) {
      output.pause();
    } else {
      output.play();
    }

    playback.value = _state.copyWith(isPlaying: !_state.isPlaying);
    _schedulePersist();
  }

  /// Used by the lock screen and headset buttons, which send explicit play/pause.
  @override
  void play() {
    if (!_state.isPlaying) togglePlayPause();
  }

  @override
  void pause() {
    if (_state.isPlaying) togglePlayPause();
  }

  /// Advances the queue. `auto` distinguishes a track ending on its own (which respects repeat and
  /// stops at the end of the queue) from the user pressing next (which always moves).
  @override
  Future<void> next({bool auto = false}) async {
    if (_state.queue.isEmpty) return;

    final isLast = _state.currentIndex >= _state.queue.length - 1;

    if (isLast && _state.repeat == RepeatMode.off) {
      if (auto) {
        // End of the queue: stop cleanly on the last track rather than wrapping.
        output.pause();
        playback.value = _state.copyWith(isPlaying: false);
      }
      return;
    }

    await _loadTrack(isLast ? 0 : _state.currentIndex + 1, autoPlay: true);
  }

  @override
  Future<void> previous() async {
    if (_state.queue.isEmpty) return;

    if (progress.value.positionMs > _restartThresholdMs || _state.currentIndex <= 0) {
      await seekTo(0);
      return;
    }

    await _loadTrack(_state.currentIndex - 1, autoPlay: true);
  }

  Future<void> skipToIndex(int index) async {
    if (index < 0 || index >= _state.queue.length) return;
    await _loadTrack(index, autoPlay: true);
  }

  Future<void> _handleTrackFinished() async {
    if (_state.repeat == RepeatMode.one) {
      await seekTo(0);
      output.play();
      return;
    }

    await next(auto: true);
  }

  @override
  Future<void> seekTo(int positionMs) async {
    final clamped = positionMs < 0 ? 0 : positionMs;

    // Update optimistically so the scrubber does not snap back before the next status tick.
    progress.value = ProgressState(positionMs: clamped, durationMs: progress.value.durationMs);
    await output.seek(clamped);
    _schedulePersist();
  }

  void setShuffle(bool enabled) {
    if (_state.shuffle == enabled) return;

    final track = _state.currentTrack;

    if (track == null) {
      playback.value = _state.copyWith(shuffle: enabled);
      _schedulePersist();
      return;
    }

    final queue = enabled
        ? shuffleKeepingCurrent(_state.sourceQueue, _state.sourceQueue.indexOf(track))
        : _state.sourceQueue;
    final index = queue.indexOf(track);

    playback.value = _state.copyWith(
      shuffle: enabled,
      queue: queue,
      // Keep playing the same track — only what comes after it changes.
      currentIndex: index < 0 ? 0 : index,
    );
    _schedulePersist();
  }

  void cycleRepeat() {
    const order = RepeatMode.values;
    playback.value = _state.copyWith(repeat: order[(_state.repeat.index + 1) % order.length]);
    _schedulePersist();
  }

  void clearError() {
    if (_state.error != null) playback.value = _state.copyWith(error: () => null);
  }

  /// Restores the previous session's queue and position. Track ids are re-hydrated against the
  /// freshly scanned library, so files deleted since last launch simply drop out of the queue.
  Future<void> restorePlayback(List<Track> library) async {
    final saved = await _readPlayback();
    if (saved == null || saved.queue.isEmpty) return;
    // Never clobber a queue the user has already started this session.
    if (_state.queue.isNotEmpty) return;

    final byId = {for (final track in library) track.id: track};
    final queue = [
      for (final id in saved.queue)
        if (byId[id] != null) byId[id]!,
    ];
    if (queue.isEmpty) return;

    final currentIndex = saved.currentIndex.clamp(0, queue.length - 1);

    playback.value = PlaybackState(
      queue: queue,
      sourceQueue: queue,
      currentIndex: currentIndex,
      shuffle: saved.shuffle,
      repeat: saved.repeat,
    );

    // Load paused: a cold start should never begin blaring audio on its own.
    await _loadTrack(currentIndex, autoPlay: false);
    if (saved.positionMs > 0) await seekTo(saved.positionMs);
  }

  /// Drops a deleted track from the queue.
  ///
  /// Both queues are filtered: `sourceQueue` is what shuffle rebuilds from, so leaving the track
  /// there would resurrect it the next time shuffle was toggled.
  ///
  /// `currentIndex` is recomputed rather than left alone — removing an entry before the current
  /// one shifts everything after it down by one, and an untouched index would silently start
  /// pointing at the neighbouring track.
  Future<void> removeTrackFromQueue(String trackId) async {
    final state = _state;
    final index = state.queue.indexWhere((track) => track.id == trackId);
    final sourceQueue = state.sourceQueue.where((track) => track.id != trackId).toList();

    if (index == -1) {
      // Not queued, but it may still be in the shuffle source.
      if (sourceQueue.length != state.sourceQueue.length) {
        playback.value = state.copyWith(sourceQueue: sourceQueue);
        _schedulePersist();
      }
      return;
    }

    final wasCurrent = index == state.currentIndex;
    final wasPlaying = state.isPlaying;
    final queue = state.queue.where((track) => track.id != trackId).toList();

    if (queue.isEmpty) {
      // Nothing left to play. Tear the session down rather than leaving the mini player pointing
      // at a file that no longer exists; shuffle and repeat are preferences, so they survive.
      _output?.pause();
      playback.value = PlaybackState(shuffle: state.shuffle, repeat: state.repeat);
      progress.value = const ProgressState();
      _schedulePersist();
      return;
    }

    final currentIndex = index < state.currentIndex
        ? state.currentIndex - 1
        : state.currentIndex.clamp(0, queue.length - 1);

    playback.value = state.copyWith(
      queue: queue,
      sourceQueue: sourceQueue,
      currentIndex: currentIndex,
    );

    // The deleted track was the one playing: move to whatever now occupies its slot, keeping the
    // play/pause state the user had rather than silently starting or stopping audio.
    if (wasCurrent) {
      await _loadTrack(currentIndex, autoPlay: wasPlaying);
      return;
    }

    _schedulePersist();
  }

  /// Tears the engine down. Only used when the app is disposed for real.
  Future<void> dispose() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    await _output?.dispose();
    _output = null;
  }
}
