import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/features/alerts/location_sounds.dart';
import 'package:pjr_accesibilitate/features/alerts/sound_alert.dart';
import 'package:pjr_accesibilitate/features/alerts/yamnet_logic.dart';

const csv = '''index,mid,display_name
0,/m/09x0r,Speech
1,/m/07pp_mv,Fire alarm
2,/m/01y3hg,"Smoke detector, smoke alarm"
3,/m/03kmc9,Siren
4,/m/0912c9,"Vehicle horn, car horn, honking"
5,/m/07cx4,Telephone bell ringing
6,/m/03wwcy,Doorbell
''';

Uint8List pcm(List<int> samples) {
  final data = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

List<double> scores(Map<int, double> values) => List.generate(7, (i) => values[i] ?? 0);

Float32List vector(List<double> values) => Float32List.fromList(values);

void main() {
  group('PcmWindower', () {
    test('cuts PCM16 into overlapping windows scaled to [-1, 1]', () {
      final windower = PcmWindower(window: 4, hop: 2);
      expect(windower.add(pcm([0, 16384, -32768])), isEmpty);
      final windows = windower.add(pcm([32767, 0, 0]));
      expect(windows, hasLength(2));
      expect(windows[0], [0, 0.5, -1, closeTo(1, 0.001)]);
      expect(windows[1], [-1, closeTo(1, 0.001), 0, 0]);
    });

    test('keeps a sample split across two chunks', () {
      final windower = PcmWindower(window: 2, hop: 2);
      final bytes = pcm([16384, -16384]);
      expect(windower.add(Uint8List.sublistView(bytes, 0, 3)), isEmpty);
      expect(windower.add(Uint8List.sublistView(bytes, 3)).single, [0.5, -0.5]);
    });
  });

  group('class mapping', () {
    test('maps YAMNet classes by display name, including quoted names', () {
      final names = parseClassMap(csv);
      expect(names[2], 'Smoke detector, smoke alarm');
      final map = mapYamnetClasses(names);
      expect(map[1], SoundKind.fireAlarm);
      expect(map[2], SoundKind.fireAlarm);
      expect(map[3], SoundKind.siren);
      expect(map[4], SoundKind.horn);
      expect(map[5], SoundKind.phone);
      expect(map[6], SoundKind.door);
      expect(map.containsKey(0), isFalse, reason: 'speech is not an alert');
    });

    test('a kind takes the best score of its classes', () {
      final map = mapYamnetClasses(parseClassMap(csv));
      final best = kindScores(scores({1: 0.1, 2: 0.6, 3: 0.2}), map);
      expect(best[SoundKind.fireAlarm], 0.6);
      expect(best[SoundKind.siren], 0.2);
    });
  });

  group('DetectionGate', () {
    final t0 = DateTime(2026, 10, 23, 16);

    test('fires after two windows in a row, then waits 10 s', () {
      final gate = DetectionGate<String>();
      expect(gate.update({'a'}, t0), isEmpty);
      expect(gate.update({'a'}, t0.add(const Duration(milliseconds: 500))), ['a']);
      expect(gate.update({'a'}, t0.add(const Duration(seconds: 1))), isEmpty);
      expect(gate.update({'a'}, t0.add(const Duration(seconds: 10))), isEmpty);
      expect(gate.update({'a'}, t0.add(const Duration(seconds: 11))), ['a']);
    });

    test('a gap resets the count', () {
      final gate = DetectionGate<String>();
      gate.update({'a'}, t0);
      gate.update({}, t0.add(const Duration(milliseconds: 500)));
      expect(gate.update({'a'}, t0.add(const Duration(seconds: 1))), isEmpty);
    });
  });

  group('SoundAnalyzer', () {
    final t0 = DateTime(2026, 10, 23, 16);
    final map = mapYamnetClasses(parseClassMap(csv));
    final hall = LocationSound(id: 'h2', label: 'Alarma halei 2', level: AlertLevel.critical, print: normalized([1, 0, 0]));

    test('turns two windows of fire alarm above 0.3 into one alert', () {
      final analyzer = SoundAnalyzer(classes: map, locationSounds: () => []);
      final window = YamnetOutput(scores(({1: 0.45})), vector([0, 1, 0]));
      expect(analyzer.analyze(window, t0), isEmpty);
      final alerts = analyzer.analyze(window, t0.add(const Duration(milliseconds: 500)));
      expect(alerts.single.kind, SoundKind.fireAlarm);
      expect(alerts.single.confidence, closeTo(0.45, 1e-6));
    });

    test('ignores scores under 0.3', () {
      final analyzer = SoundAnalyzer(classes: map, locationSounds: () => []);
      final window = YamnetOutput(scores({3: 0.29}), vector([0, 1, 0]));
      analyzer.analyze(window, t0);
      expect(analyzer.analyze(window, t0.add(const Duration(seconds: 1))), isEmpty);
    });

    test('recognises a learned sound by its fingerprint, with its own name and level', () {
      final analyzer = SoundAnalyzer(classes: map, locationSounds: () => [hall]);
      final close = YamnetOutput(scores({}), vector([0.95, 0.2, 0.1]));
      analyzer.analyze(close, t0);
      final alert = analyzer.analyze(close, t0.add(const Duration(milliseconds: 500))).single;
      expect(alert.kind, SoundKind.location);
      expect(alert.label, 'Alarma halei 2');
      expect(alert.level, AlertLevel.critical);
    });

    test('a different sound does not match the learned one', () {
      final analyzer = SoundAnalyzer(classes: map, locationSounds: () => [hall]);
      final other = YamnetOutput(scores({}), vector([0.5, 0.8, 0.3]));
      analyzer.analyze(other, t0);
      expect(analyzer.analyze(other, t0.add(const Duration(milliseconds: 500))), isEmpty);
    });
  });

  test('a fingerprint is the normalised mean of the samples', () {
    final print = fingerprint([vector([2, 0]), vector([0, 2])]);
    expect(print[0], closeTo(0.7071, 1e-3));
    expect(print[1], closeTo(0.7071, 1e-3));
    expect(similarity(print, normalized([1, 1])), closeTo(1, 1e-6));
  });
}
