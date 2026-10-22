import 'dart:typed_data';

import 'voice_engine_stub.dart' if (dart.library.js_interop) 'voice_engine_web.dart' as platform;
import 'voice_head.dart';

/// The microphone and the speaker model on the presenter's laptop. Audio never leaves the page:
/// it goes from the microphone into a 30 s buffer and from there into the model.
abstract class VoiceEngine {
  /// Opens the microphone (16 kHz, mono) and loads the model; false if either is unavailable.
  Future<bool> start();

  Future<void> stop();

  /// The last [length] of audio, oldest sample first; shorter if less has been heard.
  Float32List recent(Duration length);

  /// Unit-length speaker embedding of 16 kHz mono samples.
  Future<Float32List> embed(Float32List samples);

  /// The calibration written by training, or [VoiceHead.fallback].
  Future<VoiceHead> loadHead();

  /// Plays 16 kHz mono samples on the laptop (test-meeting review).
  Future<void> play(Float32List samples);
}

VoiceEngine createVoiceEngine() => platform.createVoiceEngine();
