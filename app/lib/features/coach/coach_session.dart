import 'dart:async';
import 'dart:typed_data';

import '../../core/voice/speaker_labeler.dart';
import 'clarity_coach.dart';
import 'coach_audio.dart';
import 'own_voice.dart';
import 'voice_activity.dart';

/// Runs the clarity coach on the colleague's microphone, all inside the page: 30 ms frames → YAMNet's
/// verdict on their second (a second without speech — typing, music, a door — is not talk, however loud)
/// → only the colleague's own voice ([OwnVoiceGate]) → the rules. YAMNet also feeds the noise rule, and
/// the other colleagues' `speaking` messages the overlap rule.
///
/// Everything is driven by the sound itself (no timers), so it keeps going while the tab is in the
/// background and the meeting app is in front.
class CoachSession {
  CoachSession(this.audio, this.coach, {SpeakerLabeler? labeler, this.onSpeaking}) {
    _gate = OwnVoiceGate(labeler, _onFrame);
  }

  static const _sampleRate = 16000;
  static const _yamnetWindow = 15600;

  /// Below this YAMNet speech score a second is not talk.
  static const _minSpeech = 0.2;

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

  /// Frames waiting for YAMNet's verdict on their second.
  final _held = <VoiceFrame>[];

  /// What happened at a time on the sound's clock (a noise score, another colleague's message), waiting
  /// for the frames heard before it, which the checks may still hold back.
  final _events = <(double, void Function())>[];
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
    final frames = _analyzer.add(chunk);
    if (noiseAvailable) {
      _held.addAll(frames);
    } else {
      frames.forEach(_gate.add);
    }
    for (final sample in chunk) {
      _recent[_heard++ % _yamnetWindow] = sample;
    }
    if (_heard >= _nextNoise) {
      _nextNoise = _heard + _sampleRate;
      _scoreNoise();
    }
  }

  /// Another colleague's page said they started or stopped talking; it counts from what this microphone
  /// hears now on, not from the frames still waiting for their checks.
  void otherSpeaking(String id, bool active) => _at(_heard / _sampleRate, () {
        _others[id] = active;
        coach.onOthersSpeaking(_others.containsValue(true), _clock);
      });

  /// The others' states are unknown again: a colleague left, or this page reconnected.
  void forgetOthers() => _at(_heard / _sampleRate, () {
        _others.clear();
        coach.onOthersSpeaking(false, _clock);
      });

  void _at(double time, void Function() event) {
    if (_events.isEmpty && time <= _clock) {
      event();
    } else {
      _events.add((time, event));
    }
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
      // Without YAMNet every loud frame counts, as before it.
      noiseAvailable = false;
      _release(double.infinity, speech: true);
      return;
    }
    final speech = speechScore(scores);
    final noise = noiseScore(scores);
    _release(time, speech: speech >= _minSpeech);
    // Voices from the meeting in the speakers are not noise to mute.
    _at(time, () => coach.onNoise(noise > speech ? noise : 0, _clock));
  }

  /// Lets through the frames heard before [until]; in a second without speech, loud frames are not voice.
  void _release(double until, {required bool speech}) {
    var count = 0;
    while (count < _held.length && _held[count].time < until) {
      count++;
    }
    for (final frame in _held.take(count)) {
      _gate.add(speech
          ? frame
          : VoiceFrame(time: frame.time, db: frame.db, voiced: false, syllable: false, noiseDb: frame.noiseDb));
    }
    _held.removeRange(0, count);
  }

  void _onFrame(VoiceFrame frame, bool own) {
    coach.onFrame(frame, own: own);
    _clock = frame.time;
    while (_events.isNotEmpty && _events.first.$1 <= _clock) {
      _events.removeAt(0).$2();
    }
    if (coach.speaking != _speaking) {
      _speaking = coach.speaking;
      onSpeaking?.call(_speaking);
    }
  }
}
