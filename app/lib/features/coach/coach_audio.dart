import 'dart:math';
import 'dart:typed_data';

import 'coach_audio_stub.dart' if (dart.library.js_interop) 'coach_audio_web.dart' as platform;

/// The colleague's microphone for the clarity coach, in the browser: 16 kHz mono, analysed in the page.
/// No audio leaves the computer.
abstract class CoachAudio {
  /// Opens the microphone (without the speaker model); false when the browser refuses it (no permission,
  /// or the page is not on https / localhost).
  Future<bool> start();

  /// Microphone samples as they arrive, about 8 chunks a second, also while the tab is in the background.
  Stream<Float32List> get chunks;

  /// YAMNet's 521 class scores for a 0.975 s window, or null when YAMNet cannot run here.
  Future<List<double>?> yamnetScores(Float32List window);

  void stop();
}

CoachAudio createCoachAudio() => platform.createCoachAudio();

/// How sure YAMNet is that a window holds speech: its strongest speech class (0–12: speech, conversation,
/// narration, shouting, whispering…).
double speechScore(List<double> scores) {
  var best = 0.0;
  for (var i = 0; i < min(scores.length, 13); i++) {
    best = max(best, scores[i]);
  }
  return best;
}

/// How much of a YAMNet window is noise the colleague could mute: the strongest class that is not speech
/// (0–12), silence or the sound of the room itself (494–520), except television and radio (518, 519).
double noiseScore(List<double> scores) {
  var best = 0.0;
  for (var i = 13; i < min(scores.length, 521); i++) {
    if (i >= 494 && i != 518 && i != 519) continue;
    best = max(best, scores[i]);
  }
  return best;
}
