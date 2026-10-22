import 'dart:typed_data';

import 'coach_audio.dart';

/// The clarity coach listens in Chrome on the colleague's computer; elsewhere there is no microphone for it.
class UnavailableCoachAudio implements CoachAudio {
  @override
  Future<bool> start() async => false;

  @override
  Stream<Float32List> get chunks => const Stream.empty();

  @override
  Future<List<double>?> yamnetScores(Float32List window) async => null;

  @override
  void stop() {}
}

CoachAudio createCoachAudio() => UnavailableCoachAudio();
