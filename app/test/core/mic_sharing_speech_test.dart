import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/speech/mic_sharing_speech.dart';

import '../fakes.dart';

void main() {
  late FakeSpeech inner;
  late List<String> calls;
  late MicSharingSpeech speech;

  setUp(() {
    inner = FakeSpeech();
    calls = [];
    speech = MicSharingSpeech(
      inner,
      takeMic: () async => calls.add('take'),
      giveBackMic: () async => calls.add('give back'),
    );
  });

  test('takes the microphone before captions start and gives it back after', () async {
    expect(await speech.start('ro-RO'), isTrue);
    expect(inner.localeId, 'ro-RO');
    await speech.stop();
    expect(calls, ['take', 'give back']);
  });

  test('a failed start gives the microphone back', () async {
    inner.available = false;
    expect(await speech.start('ro-RO'), isFalse);
    expect(calls, ['take', 'give back']);
  });

  test('starting twice takes the microphone once', () async {
    await speech.start('ro-RO');
    await speech.start('ro-RO');
    await speech.stop();
    await speech.stop();
    expect(calls, ['take', 'give back']);
  });
}
