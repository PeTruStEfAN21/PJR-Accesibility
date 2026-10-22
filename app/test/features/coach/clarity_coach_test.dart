import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/features/coach/clarity_coach.dart';
import 'package:pjr_accesibilitate/features/coach/voice_activity.dart';

const frame = 0.03;

/// Feeds the coach frames as the analyzer would: [seconds] of the colleague's voice from [from], with a
/// syllable every 1/[rate] s, loud [db] over a room at [noiseDb]; [gapEvery]/[gap] put short pauses in.
double talk(
  ClarityCoach coach,
  double from,
  double seconds, {
  double rate = 4,
  double db = -20,
  double noiseDb = -55,
  double gapEvery = 0,
  double gap = 0,
  bool own = true,
}) {
  var t = from;
  var nextSyllable = from;
  var sinceGap = 0.0;
  while (t < from + seconds) {
    var voiced = true;
    if (gapEvery > 0 && sinceGap >= gapEvery) {
      voiced = false;
      if (sinceGap >= gapEvery + gap) sinceGap = 0;
    }
    final syllable = voiced && t >= nextSyllable;
    if (syllable) nextSyllable += 1 / rate;
    coach.onFrame(VoiceFrame(time: t, db: voiced ? db : noiseDb, voiced: voiced, syllable: syllable, noiseDb: noiseDb), own: own);
    t += frame;
    sinceGap += frame;
  }
  return t;
}

/// Room sound only (the colleague is quiet) from [from] for [seconds].
double quiet(ClarityCoach coach, double from, double seconds, {double noiseDb = -55}) {
  var t = from;
  while (t < from + seconds) {
    coach.onFrame(VoiceFrame(time: t, db: noiseDb, voiced: false, syllable: false, noiseDb: noiseDb));
    t += frame;
  }
  return t;
}

const thresholds = CoachThresholds(syllablesPerSecond: 6);

void main() {
  late ClarityCoach coach;
  setUp(() => coach = ClarityCoach(thresholds: thresholds));

  test('a normal pace raises nothing', () {
    talk(coach, 0, 30, rate: 4, gapEvery: 4, gap: 0.6);
    expect(coach.current, isNull);
  });

  test('too many syllables a second over 20 s of talk: too fast', () {
    talk(coach, 0, 25, rate: 8, gapEvery: 4, gap: 0.6);
    expect(coach.current, CoachAlert.tooFast);
  });

  test('pace is only judged after 10 s of talk, and long silence forgets old talk', () {
    talk(coach, 0, 6, rate: 9, gapEvery: 4, gap: 0.6);
    expect(coach.current, isNull);
    final t = quiet(coach, 6, 60);
    talk(coach, t, 6, rate: 9, gapEvery: 4, gap: 0.6);
    expect(coach.current, isNull);
  });

  test('two stretches of 12 s without a pause within 2 minutes: make pauses', () {
    var t = talk(coach, 0, 13);
    t = quiet(coach, t, 1);
    expect(coach.current, isNull);
    talk(coach, t, 13);
    expect(coach.current, CoachAlert.noPauses);
  });

  test('five minutes of talk with only short gaps: leave room for questions', () {
    talk(coach, 0, 299, gapEvery: 5, gap: 0.9);
    expect(coach.current, isNull);
    talk(coach, 299, 3, gapEvery: 5, gap: 0.9);
    expect(coach.current, CoachAlert.longTalk);
  });

  test('a 3 s break restarts the five minutes', () {
    var t = talk(coach, 0, 200, gapEvery: 5, gap: 0.9);
    t = quiet(coach, t, 3.5);
    talk(coach, t, 150, gapEvery: 5, gap: 0.9);
    expect(coach.current, isNull);
  });

  test('a voice barely above the room: the microphone picks you up badly', () {
    talk(coach, 0, 12, db: -42, noiseDb: -55, gapEvery: 4, gap: 0.6);
    expect(coach.current, CoachAlert.weakMic);
  });

  test('a very quiet voice in a quiet room is also weak', () {
    talk(coach, 0, 12, db: -50, noiseDb: -75, gapEvery: 4, gap: 0.6);
    expect(coach.current, CoachAlert.weakMic);
  });

  test('noise while quiet, shortly after speaking: noise at your place', () {
    var t = talk(coach, 0, 5, gapEvery: 4, gap: 0.6);
    for (var i = 0; i < 7; i++) {
      t = quiet(coach, t, 1);
      coach.onNoise(0.6, t);
    }
    expect(coach.current, CoachAlert.noise);
  });

  test('noise long after the colleague last spoke is not theirs to fix', () {
    var t = talk(coach, 0, 5, gapEvery: 4, gap: 0.6);
    t = quiet(coach, t, 70);
    for (var i = 0; i < 7; i++) {
      t = quiet(coach, t, 1);
      coach.onNoise(0.6, t);
    }
    expect(coach.current, isNull);
  });

  test('talking while someone else talks for 1.5 s: overlap', () {
    final t = talk(coach, 0, 2);
    coach.onOthersSpeaking(true, t);
    talk(coach, t, 1);
    expect(coach.current, isNull);
    talk(coach, t + 1, 1);
    expect(coach.current, CoachAlert.overlap);
  });

  test('the most important alert shows first', () {
    final t = talk(coach, 0, 25, rate: 8, gapEvery: 4, gap: 0.6);
    expect(coach.current, CoachAlert.tooFast);
    coach.onOthersSpeaking(true, t);
    // tooFast stays at least 6 s, then the overlap (higher priority) takes over.
    talk(coach, t, 7, rate: 8, gapEvery: 4, gap: 0.6);
    expect(coach.current, CoachAlert.overlap);
  });

  test('an alert stays 6 s even if the cause stops, then goes', () {
    var t = talk(coach, 0, 2);
    coach.onOthersSpeaking(true, t);
    t = talk(coach, t, 2);
    expect(coach.current, CoachAlert.overlap);
    coach.onOthersSpeaking(false, t);
    t = talk(coach, t, 3);
    expect(coach.current, CoachAlert.overlap);
    talk(coach, t, 4);
    expect(coach.current, isNull);
  });

  test('the same alert does not come back within 3 minutes', () {
    var t = talk(coach, 0, 2);
    coach.onOthersSpeaking(true, t);
    t = talk(coach, t, 2);
    coach.onOthersSpeaking(false, t);
    t = talk(coach, t, 8);
    expect(coach.current, isNull);

    coach.onOthersSpeaking(true, t);
    t = talk(coach, t, 3);
    expect(coach.current, isNull); // 1 minute later: still resting

    coach.onOthersSpeaking(false, t);
    t = quiet(coach, t, 180);
    coach.onOthersSpeaking(true, t);
    talk(coach, t, 3);
    expect(coach.current, CoachAlert.overlap);
  });

  test('speaking turns on after 300 ms of voice, so a click does not flicker it, and off after a short silence', () {
    var t = talk(coach, 0, 0.2);
    expect(coach.speaking, isFalse);
    t = talk(coach, t, 0.2);
    expect(coach.speaking, isTrue);
    quiet(coach, t, 0.2);
    expect(coach.speaking, isTrue);
    quiet(coach, t + 0.2, 0.3);
    expect(coach.speaking, isFalse);
  });

  test('a single loud click is not speaking', () {
    var calls = 0;
    coach.addListener(() => calls++);
    final t = talk(coach, 0, 0.06);
    quiet(coach, t, 1);
    expect(calls, 0);
  });

  test('alerts about talking go once the colleague is quiet', () {
    final t = talk(coach, 0, 25, rate: 8, gapEvery: 4, gap: 0.6);
    expect(coach.current, CoachAlert.tooFast);
    quiet(coach, t, 7);
    expect(coach.current, isNull);
  });

  test('after 15 s of silence the earlier talk is forgotten', () {
    var t = talk(coach, 0, 9, rate: 9, gapEvery: 4, gap: 0.6);
    t = quiet(coach, t, 45);
    talk(coach, t, 1.5, rate: 3);
    expect(coach.current, isNull);
  });

  test('voices that are not the colleague do not count', () {
    talk(coach, 0, 25, rate: 9, gapEvery: 4, gap: 0.6, own: false);
    expect(coach.current, isNull);
    expect(coach.speaking, isFalse);
  });

  test('listeners hear when the colleague starts and stops speaking', () {
    var calls = 0;
    coach.addListener(() => calls++);
    final t = talk(coach, 0, 1);
    expect(calls, 1);
    quiet(coach, t, 1);
    expect(calls, 2);
  });
}
