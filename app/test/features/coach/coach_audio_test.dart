import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/features/coach/coach_audio.dart';

List<double> scores(Map<int, double> set) => [for (var i = 0; i < 521; i++) set[i] ?? 0.0];

void main() {
  test('music or typing is noise', () {
    expect(noiseScore(scores({132: 0.8, 0: 0.1})), 0.8); // Music
    expect(noiseScore(scores({378: 0.5})), 0.5); // Typing
  });

  test('a TV or a radio in the background is noise', () {
    expect(noiseScore(scores({518: 0.6})), 0.6);
    expect(noiseScore(scores({519: 0.4})), 0.4);
  });

  test('speech, silence and the sound of the room itself are not noise to fix', () {
    expect(noiseScore(scores({0: 0.9, 2: 0.7, 12: 0.5})), 0); // Speech, Conversation, Whispering
    expect(noiseScore(scores({494: 0.9, 500: 0.6, 507: 0.5, 509: 0.4, 514: 0.3})), 0); // Silence, small room, Noise, Static, White noise
  });

  test('speech is the strongest of YAMNet\'s speech classes', () {
    expect(speechScore(scores({0: 0.3, 2: 0.7})), 0.7); // Speech, Conversation
    expect(speechScore(scores({132: 0.9})), 0); // Music
  });

  test('scores that are not YAMNet\'s are not noise', () {
    expect(noiseScore(const []), 0);
  });
}
