import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/protocol.dart';
import 'package:pjr_accesibilitate/core/voice/speaker_labeler.dart';
import 'package:pjr_accesibilitate/core/voice/voice_head.dart';

import '../fakes.dart';

const rate = 16000;

Float32List silence(double seconds) => Float32List(round(seconds));

Float32List tone(double seconds, {double amplitude = 0.3}) =>
    Float32List.fromList([for (var i = 0; i < round(seconds); i++) amplitude * sin(2 * pi * 220 * i / rate)]);

int round(double seconds) => (seconds * rate).round();

Float32List join(List<Float32List> parts) => Float32List.fromList([for (final p in parts) ...p]);

/// Room noise at about -50 dBFS under everything, like a laptop across a real room hears it.
Float32List withNoise(Float32List clip, {int seed = 1}) {
  final random = Random(seed);
  return Float32List.fromList([for (final x in clip) x + 0.0045 * (random.nextDouble() * 2 - 1)]);
}

/// A vector pointing along axis [i] of a 3-dimensional space.
Float32List axis(int i) => Float32List.fromList([for (var j = 0; j < 3; j++) j == i ? 1.0 : 0.0]);

void main() {
  const head = VoiceHead(scale: 20, bias: -7, threshold: 0.5); // speaker when cosine >= 0.35
  late FakeVoiceEngine engine;
  late SpeakerLabeler labeler;
  final t0 = DateTime(2026, 10, 23, 16);

  setUp(() {
    engine = FakeVoiceEngine();
    labeler = SpeakerLabeler(engine, head);
  });

  Future<void> enrollSpeaker() async {
    engine.vectorFor = (_) => axis(0);
    expect(await labeler.enroll(tone(12)), EnrollResult.ok);
  }

  test('enrollment needs at least ten seconds of voice', () async {
    final result = await labeler.enroll(join([tone(6), silence(14)]));
    expect(result, EnrollResult.tooLittleSpeech);
    expect(labeler.enrolled, isFalse);
    expect(engine.embedded, isEmpty);
  });

  test('enrollment averages the embeddings of three-second windows', () async {
    var call = 0;
    engine.vectorFor = (_) => axis(call++ % 2);

    expect(await labeler.enroll(tone(12)), EnrollResult.ok);

    expect(engine.embedded, [48000, 48000, 48000, 48000]);
    expect(labeler.voiceprint, [closeTo(sqrt1_2, 1e-6), closeTo(sqrt1_2, 1e-6), closeTo(0, 1e-6)]);
  });

  test('each final caption is judged on the audio since the previous one, between 1.5 and 8 s', () async {
    await enrollSpeaker();
    engine.audio = tone(30);

    await labeler.labelFinal(t0);
    await labeler.labelFinal(t0.add(const Duration(seconds: 4)));
    await labeler.labelFinal(t0.add(const Duration(seconds: 24)));
    await labeler.labelFinal(t0.add(const Duration(seconds: 24, milliseconds: 500)));

    expect(engine.recentRequests, [
      const Duration(seconds: 8),
      const Duration(seconds: 4),
      const Duration(seconds: 8),
      const Duration(milliseconds: 1500),
    ]);
  });

  test('a voice close to the learned one is the speaker, another voice is the room', () async {
    await enrollSpeaker();
    engine.audio = tone(5);

    engine.vectorFor = (_) => Float32List.fromList([0.9, 0.43589, 0]);
    final judged = await labeler.judgeFinal(t0);
    expect(judged.speaker, Speaker.coordinator);
    expect(judged.score, closeTo(0.9, 1e-4));

    engine.vectorFor = (_) => axis(1);
    expect(await labeler.labelFinal(t0.add(const Duration(seconds: 5))), Speaker.public);
    expect(labeler.current, Speaker.public);
  });

  test('a very short utterance keeps the previous label and is not embedded', () async {
    await enrollSpeaker();
    engine
      ..audio = tone(4)
      ..vectorFor = (_) => axis(1);
    expect(await labeler.labelFinal(t0), Speaker.public);
    final embedded = engine.embedded.length;

    engine.audio = join([silence(3), tone(0.6), silence(1)]);
    expect(await labeler.labelFinal(t0.add(const Duration(seconds: 5))), Speaker.public);
    expect(engine.embedded.length, embedded);
  });

  test('„Vorbesc eu” labels everything as the speaker without embedding', () async {
    await enrollSpeaker();
    engine
      ..audio = tone(4)
      ..vectorFor = (_) => axis(1);
    labeler.forceSpeaker = true;
    final embedded = engine.embedded.length;

    expect(await labeler.labelFinal(t0), Speaker.coordinator);
    expect(labeler.current, Speaker.coordinator);
    expect(engine.embedded.length, embedded);
  });

  test('without a learned voice everything is the speaker', () async {
    engine.audio = tone(4);
    expect(await labeler.labelFinal(t0), Speaker.coordinator);
    expect(engine.embedded, isEmpty);
  });

  test('trimSilence removes quiet edges', () {
    final trimmed = trimSilence(join([silence(1), tone(2), silence(1)]));
    expect(trimmed.length, closeTo(2 * rate, 0.06 * rate));
  });

  test('cosine of identical, opposite and orthogonal vectors', () {
    expect(cosine(axis(0), axis(0)), closeTo(1, 1e-9));
    expect(cosine(axis(0), Float32List.fromList([-2, 0, 0])), closeTo(-1, 1e-9));
    expect(cosine(axis(0), axis(1)), closeTo(0, 1e-9));
  });

  test('a short "da" in room noise keeps the previous label', () async {
    await enrollSpeaker();
    engine
      ..audio = withNoise(tone(4))
      ..vectorFor = (_) => axis(1);
    expect(await labeler.labelFinal(t0), Speaker.public);
    final embedded = engine.embedded.length;

    engine.audio = withNoise(join([silence(3), tone(0.6), silence(1)]));
    expect(await labeler.labelFinal(t0.add(const Duration(seconds: 5))), Speaker.public);
    expect(engine.embedded.length, embedded);
  });

  test('enrollment in room noise still needs ten seconds of real voice', () async {
    expect(await labeler.enroll(withNoise(join([tone(6), silence(14)]))), EnrollResult.tooLittleSpeech);
  });

  test('an error of the model keeps the line, with the previous label', () async {
    await enrollSpeaker();
    engine.audio = tone(4);
    engine.vectorFor = (_) => throw StateError('WebGPU lost');

    final judged = await labeler.judgeFinal(t0);

    expect(judged.speaker, Speaker.coordinator);
    expect(judged.score, isNull);
    expect(judged.clip, isNotEmpty);
  });

  test('two final lines close together are judged in order, each on its own audio', () async {
    await enrollSpeaker();
    engine.audio = tone(4, amplitude: 0.3);
    engine.vectorFor = (samples) => samples.length > 40000 ? axis(0) : axis(1);

    final first = labeler.judgeFinal(t0);
    engine.audio = tone(2, amplitude: 0.3);
    final second = labeler.judgeFinal(t0.add(const Duration(seconds: 2)));

    expect((await first).speaker, Speaker.coordinator);
    expect((await second).speaker, Speaker.public);
    expect((await first).clip.length, greaterThan((await second).clip.length));
  });

  test('after the laptop speaks, the next line is judged only on what came after', () async {
    await enrollSpeaker();
    engine.audio = tone(30);
    await labeler.labelFinal(t0);
    engine.recentRequests.clear();

    labeler.startWindowAt(t0.add(const Duration(seconds: 6)));
    await labeler.labelFinal(t0.add(const Duration(seconds: 9)));

    expect(engine.recentRequests, [const Duration(seconds: 3)]);
  });

  test('confident speaker lines refine the learned voice', () async {
    await enrollSpeaker();
    engine
      ..audio = tone(4)
      ..vectorFor = (_) => Float32List.fromList([0.95, 0.31225, 0]);

    await labeler.labelFinal(t0);

    expect(labeler.voiceprint![1], greaterThan(0.01)); // moved toward the voice heard in the room
    expect(labeler.voiceprint![0], greaterThan(0.99));
  });

  test('uncertain or short lines do not change the learned voice', () async {
    await enrollSpeaker();
    final before = Float32List.fromList(labeler.voiceprint!);
    engine
      ..audio = tone(4)
      ..vectorFor = (_) => Float32List.fromList([0.5, 0.866, 0]); // speaker, but not confidently
    await labeler.labelFinal(t0);
    engine
      ..audio = tone(1.5)
      ..vectorFor = (_) => Float32List.fromList([0.95, 0.31225, 0]); // confident, but under 2 s
    await labeler.labelFinal(t0.add(const Duration(seconds: 3)));

    expect(labeler.voiceprint, before);
  });

  test('adaptation never drifts far from the enrolled voice', () async {
    await enrollSpeaker();
    engine
      ..audio = tone(4)
      ..vectorFor = (_) => Float32List.fromList([0.9, 0.43589, 0]);
    for (var i = 0; i < 200; i++) {
      await labeler.labelFinal(t0.add(Duration(seconds: 5 * i)));
    }
    expect(cosine(labeler.voiceprint!, axis(0)), greaterThanOrEqualTo(0.95 - 1e-6));
  });
}
