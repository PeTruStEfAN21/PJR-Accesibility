import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/features/alerts/sound_listening.dart';

import '../fakes.dart';

void main() {
  late FakeSounds sounds;
  late List<bool> saved;

  SoundListening create({bool wanted = false}) =>
      SoundListening(sounds, wanted: wanted, onWantedChanged: saved.add);

  setUp(() {
    sounds = FakeSounds();
    saved = [];
  });

  test('turning it on starts the microphone and remembers the choice', () async {
    final listening = create();
    expect(await listening.enable(), isTrue);
    expect(sounds.listening, isTrue);
    expect(listening.listening, isTrue);
    expect(listening.wanted, isTrue);
    expect(saved, [true]);
  });

  test('a refused microphone does not remember the choice', () async {
    sounds.canStart = false;
    final listening = create();
    expect(await listening.enable(), isFalse);
    expect(listening.wanted, isFalse);
    expect(saved, isEmpty);
  });

  test('a remembered choice starts listening on launch', () async {
    await create(wanted: true).autoStart();
    expect(sounds.listening, isTrue);
  });

  test('without the choice nothing starts on launch', () async {
    await create().autoStart();
    expect(sounds.starts, 0);
  });

  test('turning it off stops the microphone and remembers', () async {
    final listening = create(wanted: true);
    await listening.autoStart();
    await listening.disable();
    expect(sounds.listening, isFalse);
    expect(listening.wanted, isFalse);
    expect(saved, [false]);
  });

  test('captions pause listening and it comes back after them', () async {
    final listening = create(wanted: true);
    await listening.autoStart();

    await listening.hold();
    expect(sounds.listening, isFalse);
    expect(listening.paused, isTrue);

    await listening.release();
    expect(sounds.listening, isTrue);
    expect(listening.paused, isFalse);
  });

  test('listening comes back only after the last hold is released', () async {
    final listening = create(wanted: true);
    await listening.autoStart();
    await listening.hold();
    await listening.hold();
    await listening.release();
    expect(sounds.listening, isFalse);
    await listening.release();
    expect(sounds.listening, isTrue);
  });

  test('captions do not start listening that was off', () async {
    final listening = create();
    await listening.hold();
    await listening.release();
    expect(sounds.starts, 0);
    expect(listening.paused, isFalse);
  });

  test('turning it on during captions waits for them to end', () async {
    final listening = create();
    await listening.hold();
    expect(await listening.enable(), isTrue);
    expect(sounds.starts, 0);
    expect(listening.paused, isTrue);
    await listening.release();
    expect(sounds.listening, isTrue);
  });

  test('returning to the app restarts the microphone (after a call or Siri)', () async {
    final listening = create(wanted: true);
    await listening.autoStart();
    await listening.resumed();
    expect(sounds.stops, 1);
    expect(sounds.starts, 2);
    expect(sounds.listening, isTrue);
  });

  test('returning to the app during captions does not touch the microphone', () async {
    final listening = create(wanted: true);
    await listening.autoStart();
    await listening.hold();
    await listening.resumed();
    expect(sounds.starts, 1);
    expect(sounds.listening, isFalse);
  });
}
