import 'package:flutter/foundation.dart';

import 'speech_service.dart';

/// Captions and sound recognition share one microphone: this takes it from
/// sound recognition while captions run and gives it back when they stop.
class MicSharingSpeech implements SpeechService {
  MicSharingSpeech(this._inner, {required this.takeMic, required this.giveBackMic});

  final SpeechService _inner;
  final Future<void> Function() takeMic;
  final Future<void> Function() giveBackMic;
  bool _holding = false;

  @override
  Stream<SpeechSegment> get segments => _inner.segments;

  @override
  ValueListenable<SpeechState> get state => _inner.state;

  @override
  Future<bool> start(String localeId) async {
    if (!_holding) {
      _holding = true;
      await takeMic();
    }
    final ok = await _inner.start(localeId);
    if (!ok) await _giveBack();
    return ok;
  }

  @override
  Future<void> stop() async {
    await _inner.stop();
    await _giveBack();
  }

  Future<void> _giveBack() async {
    if (!_holding) return;
    _holding = false;
    await giveBackMic();
  }

  @override
  void dispose() => _inner.dispose();
}
