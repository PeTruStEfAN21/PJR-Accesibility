import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/voice/speaker_labeler.dart';
import 'package:pjr_accesibilitate/core/voice/voice_head.dart';
import 'package:pjr_accesibilitate/features/coach/clarity_coach.dart';
import 'package:pjr_accesibilitate/features/coach/coach_session.dart';

import '../../fakes.dart';
import 'signals.dart';

Float32List quiet(double seconds) => noise(seconds, 0.003, seed: 7);

/// Keys hit [perSecond] times a second: 10 ms clicks over a quiet room.
Float32List typing(double seconds, {double perSecond = 6}) {
  final out = noise(seconds, 0.003, seed: 11);
  final random = Random(5);
  for (var t = 0.1; t < seconds; t += 1 / perSecond) {
    final start = (t * rate).round();
    for (var i = 0; i < 160 && start + i < out.length; i++) {
      out[start + i] += 0.5 * (random.nextDouble() * 2 - 1);
    }
  }
  return out;
}

/// A steady chord, like music in the room.
Float32List music(double seconds) => Float32List.fromList([
      for (var i = 0; i < (seconds * rate).round(); i++)
        0.15 * (sin(2 * pi * 262 * i / rate) + sin(2 * pi * 330 * i / rate) + sin(2 * pi * 392 * i / rate)) / 3,
    ]);

List<double> scores(Map<int, double> set) => [for (var i = 0; i < 521; i++) set[i] ?? 0.0];

void main() {
  late FakeCoachAudio audio;
  late ClarityCoach coach;
  late List<bool> speaking;

  setUp(() {
    audio = FakeCoachAudio();
    coach = ClarityCoach();
    speaking = [];
  });

  CoachSession session({SpeakerLabeler? labeler}) =>
      CoachSession(audio, coach, labeler: labeler, onSpeaking: speaking.add);

  /// Hands the session the microphone in chunks of 2048 samples, as the browser does.
  Future<void> play(CoachSession session, Float32List samples) async {
    for (var i = 0; i < samples.length; i += 2048) {
      session.hear(Float32List.sublistView(samples, i, min(i + 2048, samples.length)));
      await Future<void>.delayed(Duration.zero);
    }
    await session.idle;
  }

  test('fast talk raises "too fast"; a normal pace does not', () async {
    await play(session(), talk(6, 7));
    expect(coach.current, CoachAlert.tooFast);

    coach = ClarityCoach();
    await play(session(), talk(6, 4));
    expect(coach.current, isNull);
  });

  test('the colleague\'s speaking is reported when it starts and when it stops', () async {
    final s = session();
    await play(s, talk(1, 4));
    expect(speaking, [true, false]);
    await play(s, quiet(1));
    expect(speaking, [true, false]);
  });

  test('with a learned voice, another voice from the speakers does not count', () async {
    final engine = FakeVoiceEngine()
      ..audio = talk(2, 4)
      ..vectorFor = (_) => Float32List.fromList([0, 1, 0]);
    final labeler = SpeakerLabeler(engine, const VoiceHead(scale: 20, bias: -7, threshold: 0.5))
      ..voiceprint = Float32List.fromList([1, 0, 0]);
    await play(session(labeler: labeler), talk(2, 4));
    expect(speaking, isEmpty);
  });

  test('talking while another colleague talks: overlap', () async {
    final s = session();
    s.otherSpeaking('b', true);
    await play(s, talk(1, 4));
    expect(coach.current, CoachAlert.overlap);
  });

  test('a colleague who left is no longer speaking', () async {
    final s = session();
    s.otherSpeaking('b', true);
    s.forgetOthers();
    s.otherSpeaking('c', false);
    await play(s, talk(1, 4));
    expect(coach.current, isNull);
  });

  test('typing while quiet after talking: the noise alert, not "too fast", and no speaking', () async {
    final s = session();
    audio.scores = scores({0: 0.9}); // Speech
    await play(s, talk(1, 4));
    expect(speaking, [true, false]);
    audio.scores = scores({378: 0.6}); // Typing
    await play(s, typing(12));
    expect(speaking, [true, false]);
    expect(coach.current, CoachAlert.noise);
  });

  test('music right after talking, in demo mode: the noise alert, not "make pauses"', () async {
    coach = ClarityCoach(thresholds: CoachThresholds.demo);
    final s = session();
    audio.scores = scores({0: 0.9});
    await play(s, talk(1, 4));
    audio.scores = scores({132: 0.8}); // Music
    await play(s, music(12));
    expect(coach.current, CoachAlert.noise);
  });

  test('a handover is not an overlap, even while frames wait for the checks', () async {
    coach = ClarityCoach(thresholds: const CoachThresholds(overlapHold: 0.5));
    final s = session();
    audio.scores = scores({0: 0.9});
    final colleague = talk(1, 4); // 3.6 s of voice, then 0.6 s of quiet
    final cut = (3.9 * rate).round();
    await play(s, Float32List.sublistView(colleague, 0, cut));
    s.otherSpeaking('b', true); // the other colleague starts 0.3 s after this one stopped
    await play(s, join([Float32List.sublistView(colleague, cut), quiet(3)]));
    expect(coach.current, isNull);
  });

  test('YAMNet hears each second; noise while quiet after talking: noise at your place', () async {
    final s = session();
    audio.scores = scores({0: 0.9}); // Speech
    await play(s, talk(1, 4));
    audio.scores = scores({132: 0.8}); // Music
    await play(s, quiet(9));
    expect(audio.windows, everyElement(15600));
    expect(audio.windows.length, inInclusiveRange(12, 14));
    expect(coach.current, CoachAlert.noise);
  });

  test('without YAMNet the noise alert is off and the rest goes on', () async {
    audio.scores = null;
    final s = session();
    await play(s, talk(6, 7));
    expect(coach.current, CoachAlert.tooFast);
    await play(s, quiet(9));
    expect(audio.windows, hasLength(1));
    expect(s.noiseAvailable, isFalse);
  });
}
