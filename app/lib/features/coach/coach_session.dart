import 'dart:async';
import 'dart:typed_data';

import '../../core/voice/speaker_labeler.dart';
import 'clarity_coach.dart';
import 'coach_audio.dart';
import 'own_voice.dart';
import 'voice_activity.dart';

/// Runs the clarity coach on the colleague's microphone, all inside the page: 30 ms frames → only the
/// colleague's own voice ([OwnVoiceGate]) → the rules; YAMNet once a second → the noise rule; the other
/// colleagues' `speaking` messages → the overlap rule.
///
/// Everything is driven by the sound itself (no timers), so it keeps going while the tab is in the
/// background and the meeting app is in front.
class CoachSession {
  CoachSession(this.audio, this.coach, {SpeakerLabeler? labeler, this.onSpeaking}) {
    _gate = OwnVoiceGate(labeler, _onFrame);
  }

  static const _sampleRate = 16000;
  static const _yamnetWindow = 15600;

  final CoachAudio audio;
  final ClarityCoach coach;

  /// The colleague started or stopped talking (the other colleagues' pages need it for their overlap alert).
  final void Function(bool speaking)? onSpeaking;

  final _analyzer = FrameAnalyzer();
  late final OwnVoiceGate _gate;
  StreamSubscription<Float32List>? _chunks;

  /// The last YAMNet window of sound, as a ring.
  final _recent = Float32List(_yamnetWindow);
  int _heard = 0;
  int _nextNoise = _sampleRate;
  bool _scoring = false;

  /// Noise scores waiting for the frames (held back by the voice check) to reach their time.
  final _noise = <(double, double)>[];
  double _clock = 0;
  bool _speaking = false;
  final _others = <String, bool>{};

  /// False once YAMNet failed to run here: the noise alert is then off.
  bool noiseAvailable = true;

  /// Completes once every frame heard so far has reached the coach.
  Future<void> get idle => _gate.idle;

  void start() => _chunks ??= audio.chunks.listen(hear);

  void stop() {
    _chunks?.cancel();
    _chunks = null;
  }

  /// Microphone samples, 16 kHz mono.
  void hear(Float32List chunk) {
    for (final frame in _analyzer.add(chunk)) {
      _gate.add(frame);
    }
    for (final sample in chunk) {
      _recent[_heard++ % _yamnetWindow] = sample;
    }
    if (_heard >= _nextNoise) {
      _nextNoise = _heard + _sampleRate;
      _scoreNoise();
    }
  }

  /// Another colleague's page said they started or stopped talking.
  void otherSpeaking(String id, bool active) {
    _others[id] = active;
    coach.onOthersSpeaking(_others.containsValue(true), _clock);
  }

  /// The others' states are unknown again: a colleague left, or this page reconnected.
  void forgetOthers() {
    _others.clear();
    coach.onOthersSpeaking(false, _clock);
  }

  Future<void> _scoreNoise() async {
    if (_scoring || !noiseAvailable) return;
    _scoring = true;
    final start = _heard % _yamnetWindow;
    final window = Float32List(_yamnetWindow)
      ..setRange(0, _yamnetWindow - start, _recent, start)
      ..setRange(_yamnetWindow - start, _yamnetWindow, _recent);
    final time = _heard / _sampleRate;
    final scores = await audio.yamnetScores(window);
    _scoring = false;
    if (scores == null) {
      noiseAvailable = false;
      return;
    }
    _noise.add((time, noiseScore(scores)));
    _flushNoise();
  }

  void _onFrame(VoiceFrame frame, bool own) {
    coach.onFrame(frame, own: own);
    _clock = frame.time;
    _flushNoise();
    if (coach.speaking != _speaking) {
      _speaking = coach.speaking;
      onSpeaking?.call(_speaking);
    }
  }

  void _flushNoise() {
    while (_noise.isNotEmpty && _noise.first.$1 <= _clock) {
      coach.onNoise(_noise.removeAt(0).$2, _clock);
    }
  }
}
