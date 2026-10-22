import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/voice/voice_head.dart';

void main() {
  test('probability is the calibrated logistic of the cosine, compared with the threshold', () {
    const head = VoiceHead(scale: 20, bias: -7, threshold: 0.5);
    expect(head.probability(0.35), closeTo(0.5, 1e-9));
    expect(head.isSpeaker(0.36), isTrue);
    expect(head.isSpeaker(0.34), isFalse);
  });

  test('reads every key the training pipeline writes', () {
    final head = VoiceHead.fromJson({
      'model': 'redimnet2-b6-vb2+vox2_v0-lm',
      'scale': 12.5,
      'bias': -6,
      'threshold': 0.4,
      'min_voiced_ms': 800,
      'enroll_min_voiced_ms': 9000,
      'window_ms': 2500,
    });
    expect(head.model, 'redimnet2-b6-vb2+vox2_v0-lm');
    expect(head.scale, 12.5);
    expect(head.bias, -6.0);
    expect(head.threshold, 0.4);
    expect(head.minVoicedMs, 800);
    expect(head.enrollMinVoicedMs, 9000);
    expect(head.windowMs, 2500);
  });
}
