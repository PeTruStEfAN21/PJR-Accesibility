import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/voice/speaker_labeler.dart';
import 'package:pjr_accesibilitate/core/voice/voice_head.dart';
import 'package:pjr_accesibilitate/features/coach/own_voice.dart';
import 'package:pjr_accesibilitate/features/coach/voice_activity.dart';

import '../../fakes.dart';

Float32List tone(double seconds) =>
    Float32List.fromList([for (var i = 0; i < (seconds * 16000).round(); i++) 0.3 * sin(2 * pi * 220 * i / 16000)]);

Float32List axis(int i) => Float32List.fromList([for (var j = 0; j < 3; j++) j == i ? 1.0 : 0.0]);

/// Frames of [seconds] from [from]: voice, or silence.
List<VoiceFrame> frames(double from, double seconds, {bool voiced = true}) => [
      for (var t = from; t < from + seconds - 1e-9; t += 0.03)
        VoiceFrame(time: t, db: voiced ? -20 : -60, voiced: voiced, syllable: false),
    ];

void main() {
  const head = VoiceHead(scale: 20, bias: -7, threshold: 0.5); // the colleague when cosine >= 0.35
  late FakeVoiceEngine engine;
  late SpeakerLabeler labeler;
  late List<(double, bool)> out;

  setUp(() {
    engine = FakeVoiceEngine()..audio = tone(10);
    labeler = SpeakerLabeler(engine, head);
    out = [];
  });

  OwnVoiceGate gate(SpeakerLabeler? labeler) => OwnVoiceGate(labeler, (frame, own) => out.add((frame.time, own)));

  test('without a learned voice every frame is the colleague\'s, right away', () {
    final g = gate(null);
    frames(0, 0.3).forEach(g.add);
    expect(out.length, 10);
    expect(out.every((f) => f.$2), isTrue);
  });

  test('with a learned voice, a second of voice is held, judged, then let through as the colleague\'s', () async {
    labeler.voiceprint = axis(0);
    engine.vectorFor = (_) => axis(0);
    final g = gate(labeler);
    frames(0, 0.9).forEach(g.add);
    await g.idle;
    expect(out, isEmpty);

    frames(0.9, 0.2).forEach(g.add);
    await g.idle;
    expect(out.length, greaterThanOrEqualTo(34));
    expect(out.every((f) => f.$2), isTrue);
    expect(engine.embedded, hasLength(1));
  });

  test('another voice, from the speakers, does not count', () async {
    labeler.voiceprint = axis(0);
    engine.vectorFor = (_) => axis(1);
    final g = gate(labeler);
    frames(0, 1.2).forEach(g.add);
    await g.idle;
    expect(out, isNotEmpty);
    expect(out.any((f) => f.$2), isFalse);
  });

  test('a short utterance is judged once the voice stops for half a second', () async {
    labeler.voiceprint = axis(0);
    engine.vectorFor = (_) => axis(1);
    final g = gate(labeler);
    frames(0, 0.4).forEach(g.add);
    frames(0.4, 0.45, voiced: false).forEach(g.add);
    await g.idle;
    expect(out, isEmpty);

    frames(0.85, 0.1, voiced: false).forEach(g.add);
    await g.idle;
    expect(out.length, greaterThanOrEqualTo(30));
    expect(out.any((f) => f.$2), isFalse);
  });

  test('silence goes straight through, and frames come out in the order they went in', () async {
    labeler.voiceprint = axis(0);
    engine.vectorFor = (_) => axis(0);
    final g = gate(labeler);
    frames(0, 0.3, voiced: false).forEach(g.add);
    await g.idle;
    expect(out.length, 10);

    frames(0.3, 1.05).forEach(g.add);
    frames(1.35, 0.3, voiced: false).forEach(g.add);
    await g.idle;
    final times = [for (final f in out) f.$1];
    expect(times, [for (var i = 0; i < times.length; i++) closeTo(i * 0.03, 1e-9)]);
  });
}
