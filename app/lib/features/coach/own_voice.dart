import 'dart:async';

import '../../core/protocol.dart';
import '../../core/voice/speaker_labeler.dart';
import 'voice_activity.dart';

/// Lets the microphone's frames through, in order, with whether they are the colleague's own voice.
///
/// Without a learned voice every frame is the colleague's (the coach screen then says the alerts are
/// approximate: the microphone may also hear the meeting from the speakers). With one, voice is held until
/// a second of it is heard, or until it stops for half a second; that audio is judged against the learned
/// voice ([SpeakerLabeler.judgeFinal]) and the held frames go out with the verdict. The coach then runs
/// about a second behind, and other voices from the speakers do not count.
class OwnVoiceGate {
  OwnVoiceGate(SpeakerLabeler? labeler, this.onFrame) : _labeler = (labeler?.enrolled ?? false) ? labeler : null;

  static const _segment = 1.0;
  static const _endGap = 0.5;
  static const _frameSeconds = 0.03;

  final SpeakerLabeler? _labeler;
  final void Function(VoiceFrame frame, bool own) onFrame;

  final _pending = <VoiceFrame>[];
  int _voicedFrames = 0;
  double _lastVoice = double.negativeInfinity;
  bool _own = true;
  Future<void> _chain = Future.value();

  /// Completes once every frame added so far has gone out.
  Future<void> get idle => _chain;

  void add(VoiceFrame frame) {
    final labeler = _labeler;
    if (labeler == null) {
      onFrame(frame, true);
      return;
    }
    _pending.add(frame);
    if (frame.voiced) {
      _voicedFrames++;
      _lastVoice = frame.time;
    }
    if (_voicedFrames == 0) {
      _release(null);
    } else if (_voicedFrames * _frameSeconds >= _segment || frame.time - _lastVoice >= _endGap) {
      // The audio is taken now, while it is still the last thing the microphone heard.
      _release(labeler.judgeFinal(DateTime.now()));
    }
  }

  void _release(Future<Judgement>? judging) {
    final batch = List.of(_pending);
    _pending.clear();
    _voicedFrames = 0;
    _chain = _chain.then((_) async {
      if (judging != null) _own = (await judging).speaker == Speaker.coordinator;
      for (final frame in batch) {
        onFrame(frame, _own);
      }
    });
  }
}
