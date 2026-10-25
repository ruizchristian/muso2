// `AudioDeviceType` is marked experimental in audio_session, but it is the only way to tell a
// headphone disconnect apart from any other route change.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:audio_service/audio_service.dart' as svc;
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../media/track.dart';

/// One status push from the audio output to the engine.
class OutputStatus {
  const OutputStatus({
    required this.playing,
    required this.buffering,
    required this.positionMs,
    required this.durationMs,
    this.didJustFinish = false,
  });

  final bool playing;
  final bool buffering;
  final int positionMs;
  final int durationMs;

  /// True exactly once per load, on the push where the track reached its end.
  final bool didJustFinish;
}

/// What the lock screen, notification and headset buttons can ask the engine to do.
abstract interface class TransportCommands {
  void play();
  void pause();
  Future<void> next({bool auto});
  Future<void> previous();
  Future<void> seekTo(int positionMs);
}

/// The engine's view of an audio player. Kept this narrow so the queue logic can be tested
/// against a fake without a platform player.
abstract class AudioOutput {
  void Function(OutputStatus status)? onStatus;
  TransportCommands? commands;

  Future<void> init();

  /// Loads `uri` paused. Returns false when the file cannot be opened.
  Future<bool> load(String uri, Track track);
  void play();
  void pause();
  Future<void> seek(int positionMs);
  Future<void> dispose();
}

/// Output routes whose removal should stop the music rather than blast it out of the speaker.
///
/// Bluetooth SCO is left out on purpose: it is the headset's call/voice-assistant link and comes
/// and goes on its own while A2DP (the music link) stays connected. Pausing on it stopped the
/// music at random and, after a call, cancelled just_audio's automatic resume.
const _pauseOnDisconnectTypes = {
  AudioDeviceType.bluetoothA2dp,
  AudioDeviceType.wiredHeadset,
  AudioDeviceType.wiredHeadphones,
  AudioDeviceType.usbAudio,
};

/// Lock-screen ±10 s buttons. The icons are the app's own drawables (`res/drawable`) so the
/// buttons read as "10 seconds" rather than audio_service's generic fast-forward chevrons.
const _rewind10 = svc.MediaControl(
  androidIcon: 'drawable/ic_replay_10',
  label: 'Back 10 seconds',
  action: svc.MediaAction.rewind,
);

const _forward10 = svc.MediaControl(
  androidIcon: 'drawable/ic_forward_10',
  label: 'Forward 10 seconds',
  action: svc.MediaAction.fastForward,
);

/// Status push rate. 500ms keeps the scrubber smooth without flooding the UI isolate.
const _updateInterval = Duration(milliseconds: 500);

class JustAudioOutput extends AudioOutput {
  AudioPlayer? _player;
  _MusoAudioHandler? _handler;
  AudioSession? _session;

  /// Another app took audio focus away (a call, a video, a voice message, navigation…) and has
  /// not given it back yet. See [_play].
  bool _focusLost = false;
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _initialised = false;
  bool _finishReported = false;

  AudioPlayer get _p => _player ??= _createPlayer();

  AudioPlayer _createPlayer() {
    final player = AudioPlayer();

    _subscriptions
      ..add(player.playerStateStream.listen((_) => _emit()))
      ..add(
        player
            .createPositionStream(minPeriod: _updateInterval, maxPeriod: _updateInterval)
            .listen((_) => _emit()),
      )
      ..add(player.durationStream.listen((_) => _emit()))
      // Load failures arrive here as stream errors; `load` already reports them, so they are
      // swallowed rather than surfacing as unhandled exceptions.
      ..add(player.playbackEventStream.listen(_broadcast, onError: (Object _) {}));

    return player;
  }

  void _emit() {
    final player = _p;
    final state = player.processingState;
    final finished = state == ProcessingState.completed;
    final didJustFinish = finished && !_finishReported;
    if (didJustFinish) _finishReported = true;

    onStatus?.call(
      OutputStatus(
        // just_audio keeps `playing` true after the end of a track; the engine should not.
        playing: player.playing && !finished,
        buffering: state == ProcessingState.loading || state == ProcessingState.buffering,
        positionMs: player.position.inMilliseconds,
        durationMs: player.duration?.inMilliseconds ?? 0,
        didJustFinish: didJustFinish,
      ),
    );
  }

  /// Mirrors the player into the media notification and lock screen.
  void _broadcast(PlaybackEvent event) {
    final handler = _handler;
    if (handler == null) return;

    final player = _p;
    final playing = player.playing && player.processingState != ProcessingState.completed;

    handler.playbackState.add(
      svc.PlaybackState(
        controls: [
          svc.MediaControl.skipToPrevious,
          if (playing) svc.MediaControl.pause else svc.MediaControl.play,
          svc.MediaControl.skipToNext,
          // On Android 13+ these become the player's two extra slots beside previous/next. The
          // jump size is AudioServiceConfig's 10-second default.
          _rewind10,
          _forward10,
        ],
        systemActions: const {
          svc.MediaAction.seek,
          svc.MediaAction.seekForward,
          svc.MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: switch (player.processingState) {
          ProcessingState.idle => svc.AudioProcessingState.idle,
          ProcessingState.loading => svc.AudioProcessingState.loading,
          ProcessingState.buffering => svc.AudioProcessingState.buffering,
          ProcessingState.ready => svc.AudioProcessingState.ready,
          ProcessingState.completed => svc.AudioProcessingState.completed,
        },
        playing: playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
      ),
    );
  }

  @override
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    final session = _session = await AudioSession.instance;
    // Music: plays in the background, takes exclusive focus so it does not talk over another
    // player, and ducks/pauses for calls (just_audio handles those interruptions itself).
    await session.configure(const AudioSessionConfiguration.music());

    _subscriptions
      ..add(session.interruptionEventStream.listen((event) => _focusLost = event.begin))
      // Headphones unplugged. Android broadcasts this without revoking audio focus, so focus
      // handling never sees it.
      ..add(session.becomingNoisyEventStream.listen((_) => commands?.pause()))
      // Some devices skip the "becoming noisy" broadcast when Bluetooth is switched off
      // manually, so the output device list is watched directly as well.
      ..add(
        session.devicesChangedEventStream.listen((event) {
          final lostOutput = event.devicesRemoved.any(
            (device) => device.isOutput && _pauseOnDisconnectTypes.contains(device.type),
          );
          if (lostOutput) commands?.pause();
        }),
      );

    try {
      _handler = await svc.AudioService.init(
        builder: () => _MusoAudioHandler(this),
        config: const svc.AudioServiceConfig(
          androidNotificationChannelId: 'com.example.music.playback',
          androidNotificationChannelName: 'Playback',
          // Lock-screen controls are also what keeps Android alive in the background.
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          // The default thumbnail is 192px, which the lock screen stretches to full width.
          artDownscaleWidth: 512,
          artDownscaleHeight: 512,
        ),
      );
    } catch (_) {
      // No media session on this platform; playback still works in the foreground.
    }
  }

  @override
  Future<bool> load(String uri, Track track) async {
    _finishReported = false;

    _handler?.mediaItem.add(
      svc.MediaItem(
        id: track.id,
        title: track.title,
        artist: track.artist,
        album: track.album,
        duration: Duration(milliseconds: track.durationMs),
        // The song's own media-store entry. With `loadThumbnailUri` set, audio_service asks the
        // media store's thumbnailer for it, which returns the cover embedded in the file — the
        // same source as the in-app artwork. A file without a cover just shows none.
        artUri: Uri.parse('content://media/external/audio/media/${track.id}'),
        // Must be a string: the Android side reads it with getString, so 	rue counts as unset.
        extras: const {'loadThumbnailUri': 'true'},
      ),
    );

    try {
      await _p.setAudioSource(AudioSource.uri(Uri.parse(uri)));
      return true;
    } on PlayerInterruptedException {
      // Superseded by a newer load; the engine discards this result by token.
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void play() => unawaited(_play().catchError((Object _) {}));

  /// audio_session only asks Android for focus when it believes it does not hold it, and it still
  /// believes so after a transient loss. Pressing play in that state skipped the request, so the
  /// player ran (the app showed it playing, the scrubber moved) while Android kept it muted for
  /// not owning focus. Dropping the stale request first makes `play` ask for focus for real; if
  /// Android refuses, as during a call, just_audio reports the player as paused instead.
  Future<void> _play() async {
    final session = _session;
    if (_focusLost && session != null && !_p.playing) {
      _focusLost = false;
      await session.setActive(false);
    }
    await _p.play();
  }

  @override
  void pause() => unawaited(_p.pause().catchError((Object _) {}));

  @override
  Future<void> seek(int positionMs) async {
    try {
      await _p.seek(Duration(milliseconds: positionMs));
    } catch (_) {
      // Seeking an unloaded source is a no-op, not an error worth surfacing.
    }
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _player?.dispose();
    _player = null;
  }
}

/// Routes lock-screen, notification and headset actions into the engine, so they follow exactly
/// the same queue rules as the in-app buttons.
class _MusoAudioHandler extends svc.BaseAudioHandler with svc.SeekHandler {
  _MusoAudioHandler(this._output);

  final JustAudioOutput _output;

  TransportCommands? get _commands => _output.commands;

  @override
  Future<void> play() async => _commands?.play();

  @override
  Future<void> pause() async => _commands?.pause();

  @override
  Future<void> stop() async => _commands?.pause();

  @override
  Future<void> skipToNext() async => _commands?.next();

  @override
  Future<void> skipToPrevious() async => _commands?.previous();

  @override
  Future<void> seek(Duration position) async => _commands?.seekTo(position.inMilliseconds);
}
