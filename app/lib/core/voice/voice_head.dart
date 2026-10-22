import 'dart:math';

/// How the page turns a cosine similarity into "speaker or room". Written by `ml/voice` (echo_voice.ship)
/// into `web/voice/voice_head.json` after training and calibration.
class VoiceHead {
  const VoiceHead({
    required this.scale,
    required this.bias,
    required this.threshold,
    this.model = 'unknown',
    this.minVoicedMs = 1000,
    this.enrollMinVoicedMs = 10000,
    this.windowMs = 3000,
    this.adaptThreshold = 0.98,
    this.adaptRate = 0.1,
    this.adaptMinCosine = 0.95,
    this.adaptMinVoicedMs = 2000,
  });

  /// Used until a calibrated file loads: speaker when the cosine is at least 0.35.
  static const fallback = VoiceHead(scale: 20, bias: -7, threshold: 0.5, model: 'redimnet2-b6-vb2+vox2_v0-lm');

  factory VoiceHead.fromJson(Map<String, dynamic> json) => VoiceHead(
        model: json['model'] as String? ?? 'unknown',
        scale: (json['scale'] as num).toDouble(),
        bias: (json['bias'] as num).toDouble(),
        threshold: (json['threshold'] as num).toDouble(),
        minVoicedMs: (json['min_voiced_ms'] as num?)?.toInt() ?? 1000,
        enrollMinVoicedMs: (json['enroll_min_voiced_ms'] as num?)?.toInt() ?? 10000,
        windowMs: (json['window_ms'] as num?)?.toInt() ?? 3000,
        adaptThreshold: (json['adapt_threshold'] as num?)?.toDouble() ?? 0.98,
        adaptRate: (json['adapt_rate'] as num?)?.toDouble() ?? 0.1,
        adaptMinCosine: (json['adapt_min_cosine'] as num?)?.toDouble() ?? 0.95,
        adaptMinVoicedMs: (json['adapt_min_voiced_ms'] as num?)?.toInt() ?? 2000,
      );

  final String model;
  final double scale;
  final double bias;
  final double threshold;

  /// Shorter utterances say too little about a voice: they keep the previous label.
  final int minVoicedMs;

  /// Voice needed in the enrollment recording.
  final int enrollMinVoicedMs;

  /// Enrollment is cut into windows of this length; their embeddings are averaged.
  final int windowMs;

  /// Learning during the meeting: a line at least this likely to be the speaker's, with enough voice,
  /// moves the learned voice by [adaptRate] toward it, never further than [adaptMinCosine] from enrollment.
  final double adaptThreshold;
  final double adaptRate;
  final double adaptMinCosine;
  final int adaptMinVoicedMs;

  double probability(double cosine) => 1 / (1 + exp(-(scale * cosine + bias)));

  bool isSpeaker(double cosine) => probability(cosine) >= threshold;

  /// The similarity at which a line starts counting as the speaker's.
  double get cosineThreshold => (log(threshold / (1 - threshold)) - bias) / scale;
}
