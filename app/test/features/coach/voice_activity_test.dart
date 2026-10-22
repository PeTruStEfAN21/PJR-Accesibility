import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/features/coach/voice_activity.dart';

const rate = 16000;

/// A voice-like test signal: a fixed three-tone carrier whose loudness rises and falls [syllablesPerSecond]
/// times a second, like syllables. Deterministic, so the Python port can count the same peaks.
Float32List syllables(double seconds, double syllablesPerSecond, {double amplitude = 0.3}) {
  final n = (seconds * rate).round();
  return Float32List.fromList([
    for (var i = 0; i < n; i++)
      () {
        final t = i / rate;
        final carrier = sin(2 * pi * 220 * t) + 0.5 * sin(2 * pi * 440 * t + 1) + 0.3 * sin(2 * pi * 880 * t + 2);
        final hump = max(0.0, sin(2 * pi * syllablesPerSecond * t));
        return amplitude * (0.05 + hump) * carrier / 1.8;
      }(),
  ]);
}

Float32List noise(double seconds, double amplitude, {int seed = 3}) {
  final random = Random(seed);
  return Float32List.fromList([for (var i = 0; i < (seconds * rate).round(); i++) amplitude * (random.nextDouble() * 2 - 1)]);
}

Float32List join(List<Float32List> parts) => Float32List.fromList([for (final p in parts) ...p]);

List<VoiceFrame> analyze(Float32List samples, {int chunk = 2048}) {
  final analyzer = FrameAnalyzer();
  return [
    for (var i = 0; i < samples.length; i += chunk)
      ...analyzer.add(Float32List.sublistView(samples, i, min(i + chunk, samples.length))),
  ];
}

void main() {
  test('frames are 30 ms long and carry their time', () {
    final frames = analyze(syllables(1, 4));
    expect(frames, hasLength(33)); // 1 s / 30 ms, the last partial frame waits for more sound
    expect(frames[1].time, closeTo(0.03, 1e-9));
  });

  test('four syllables a second are counted as about four a second', () {
    final frames = analyze(syllables(10, 4));
    final counted = frames.where((f) => f.syllable).length;
    expect(counted, inInclusiveRange(34, 46)); // 40 ± 15%
  });

  test('a faster voice gives more syllables', () {
    final slow = analyze(syllables(10, 3)).where((f) => f.syllable).length;
    final fast = analyze(syllables(10, 6)).where((f) => f.syllable).length;
    expect(fast, greaterThan(slow * 1.6));
  });

  test('silence is never voice', () {
    expect(analyze(Float32List(3 * rate)).where((f) => f.voiced), isEmpty);
  });

  test('steady background noise is not voice, the voice on top of it is', () {
    final background = noise(5, 0.004);
    final roomUnderVoice = noise(5, 0.004, seed: 9);
    final frames = analyze(join([background, Float32List.fromList([
      for (final (i, s) in syllables(5, 4).indexed) s + roomUnderVoice[i],
    ])]));
    final noiseOnly = frames.where((f) => f.time > 1 && f.time < 4.9);
    final withVoice = frames.where((f) => f.time > 5.5);
    expect(noiseOnly.where((f) => f.voiced).length / noiseOnly.length, lessThan(0.05));
    expect(withVoice.where((f) => f.voiced).length / withVoice.length, greaterThan(0.5));
  });

  test('the result does not depend on how the sound is cut into chunks', () {
    final signal = syllables(4, 5);
    final big = analyze(signal, chunk: 4096);
    final small = analyze(signal, chunk: 333);
    expect(small.map((f) => (f.voiced, f.syllable)), big.map((f) => (f.voiced, f.syllable)));
  });

  test('the parity signal gives the count the Python port must also give', () {
    // Same signal in ml/voice/tests/test_speech_rate.py; both must count exactly this many.
    expect(analyze(syllables(6, 4.5)).where((f) => f.syllable).length, 27);
  });
}
