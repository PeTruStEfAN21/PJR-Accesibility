import 'dart:typed_data';

import 'voice_engine.dart';
import 'voice_head.dart';

/// Phones do not recognise the speaker's voice: the presenter page in Chrome does.
class UnavailableVoiceEngine implements VoiceEngine {
  @override
  Future<bool> start() async => false;

  @override
  Future<void> stop() async {}

  @override
  Float32List recent(Duration length) => Float32List(0);

  @override
  Future<Float32List> embed(Float32List samples) => throw UnsupportedError('no speaker model on this platform');

  @override
  Future<VoiceHead> loadHead() async => VoiceHead.fallback;

  @override
  Future<void> play(Float32List samples) async {}
}

VoiceEngine createVoiceEngine() => UnavailableVoiceEngine();
