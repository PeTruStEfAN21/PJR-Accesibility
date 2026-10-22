import 'dart:math';
import 'dart:typed_data';

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

Float32List plus(Float32List a, Float32List b) => Float32List.fromList([for (var i = 0; i < a.length; i++) a[i] + b[i]]);

/// Talk at [perSecond] syllables a second over room noise: [cycles] times 3.6 s of voice and a 0.6 s pause.
Float32List talk(int cycles, double perSecond) => join([
      for (var i = 0; i < cycles; i++) ...[
        plus(syllables(3.6, perSecond), noise(3.6, 0.003, seed: i)),
        noise(0.6, 0.003, seed: 100 + i),
      ],
    ]);
