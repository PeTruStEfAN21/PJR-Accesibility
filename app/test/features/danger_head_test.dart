import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/features/alerts/sound_alert.dart';
import 'package:pjr_accesibilitate/features/alerts/yamnet_logic.dart';

/// Two-dimensional toy head: background vs fire alarm.
final toy = DangerHead.fromJson({
  'labels': ['background', 'fire_alarm', 'unknown_label'],
  'thresholds': {'fire_alarm': 0.9, 'unknown_label': 0.5},
  'bias': [0.0, 0.0, -100.0],
  'weights': [
    [1.0, 0.0],
    [0.0, 5.0],
    [0.0, 0.0],
  ],
});

void main() {
  test('softmax over the weights, mapped onto alert kinds; unknown labels are ignored', () {
    final p = toy.predict(Float32List.fromList([0, 1]));
    expect(p.keys, [SoundKind.fireAlarm]);
    expect(p[SoundKind.fireAlarm], closeTo(1 / (1 + 1 / 148.413), 1e-3));
    expect(toy.threshold(SoundKind.fireAlarm), 0.9);
  });

  for (final asset in ['assets/models/danger_head.json', 'assets/models/danger_head_web.json']) {
    test('$asset gives the same probabilities in Dart as in the Python training', () {
      final json = jsonDecode(File(asset).readAsStringSync()) as Map<String, dynamic>;
      final head = DangerHead.fromJson(json);
      final check = json['check'] as Map<String, dynamic>;
      final embedding = Float32List.fromList([for (final v in check['embedding'] as List) (v as num).toDouble()]);
      final expected = [for (final v in check['probabilities'] as List) (v as num).toDouble()];

      final p = head.predict(embedding);
      expect(p[SoundKind.fireAlarm], closeTo(expected[1], 1e-4));
      expect(p[SoundKind.siren], closeTo(expected[2], 1e-4));
      expect(p[SoundKind.horn], closeTo(expected[3], 1e-4));
      expect(p[SoundKind.glassBreak], closeTo(expected[4], 1e-4));
    });
  }

  group('SoundAnalyzer with the trained head', () {
    final t0 = DateTime(2026, 10, 23, 16);
    final names = mapYamnetClasses(['Speech', 'Fire alarm']);
    List<double> scores({double fire = 0}) => [0, fire];

    test('the trained head alone raises the alert when YAMNet names miss it', () {
      final analyzer = SoundAnalyzer(classes: names, locationSounds: () => [], head: toy);
      final window = YamnetOutput(scores(), Float32List.fromList([0, 1]));
      analyzer.analyze(window, t0);
      expect(analyzer.analyze(window, t0.add(const Duration(milliseconds: 500))).single.kind, SoundKind.fireAlarm);
    });

    test('YAMNet names alone still raise it when the head is unsure', () {
      final analyzer = SoundAnalyzer(classes: names, locationSounds: () => [], head: toy);
      final window = YamnetOutput(scores(fire: 0.5), Float32List.fromList([1, 0]));
      analyzer.analyze(window, t0);
      expect(analyzer.analyze(window, t0.add(const Duration(milliseconds: 500))).single.kind, SoundKind.fireAlarm);
    });

    test('neither sure: nothing', () {
      final analyzer = SoundAnalyzer(classes: names, locationSounds: () => [], head: toy);
      final window = YamnetOutput(scores(fire: 0.1), Float32List.fromList([1, 0.2]));
      analyzer.analyze(window, t0);
      expect(analyzer.analyze(window, t0.add(const Duration(milliseconds: 500))), isEmpty);
    });
  });
}
