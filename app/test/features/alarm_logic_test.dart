import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/features/alerts/sound_alert.dart';
import 'package:pjr_accesibilitate/features/emergency/alarm_logic.dart';
import 'package:pjr_accesibilitate/l10n/app_localizations_ro.dart';

Alarm alarmAt(double lat, {AlarmKind kind = AlarmKind.fire}) =>
    Alarm(id: 'a', kind: kind, at: DateTime(2026, 10, 23), lat: lat, lon: 26.0, accuracyM: 10);

// On the same longitude, 1 degree of latitude is 111 195 m.
double latFor(double meters) => 44.0 + meters / 111195;

void main() {
  group('distanceMeters', () {
    test('same point is 0', () {
      expect(distanceMeters(44.4268, 26.1025, 44.4268, 26.1025), 0);
    });

    test('Bucharest to Ploiesti is about 57 km', () {
      expect(distanceMeters(44.4268, 26.1025, 44.9419, 26.0225), closeTo(57000, 1000));
    });
  });

  group('inRange', () {
    test('null position counts as in range', () {
      expect(inRange(alarmAt(44.0), null), isTrue);
    });

    test('499 m with accuracy 0 is in, 501 m is out', () {
      expect(inRange(alarmAt(latFor(499)), const Position(lat: 44.0, lon: 26.0, accuracyM: 0)), isTrue);
      expect(inRange(alarmAt(latFor(501)), const Position(lat: 44.0, lon: 26.0, accuracyM: 0)), isFalse);
    });

    test('accuracy widens the range, capped at 100 m', () {
      expect(inRange(alarmAt(latFor(590)), const Position(lat: 44.0, lon: 26.0, accuracyM: 90)), isTrue);
      expect(inRange(alarmAt(latFor(650)), const Position(lat: 44.0, lon: 26.0, accuracyM: 400)), isFalse);
    });
  });

  group('AlarmKind', () {
    test('wire round trip', () {
      for (final k in AlarmKind.values) {
        expect(AlarmKind.fromWire(k.wire), k);
      }
      expect(AlarmKind.fromWire('flood'), isNull);
    });

    test('maps onto sound kind and level', () {
      expect(AlarmKind.fire.sound, SoundKind.fireAlarm);
      expect(AlarmKind.evacuation.sound, SoundKind.location);
      expect(AlarmKind.siren.sound, SoundKind.siren);
      expect(AlarmKind.machine.sound, SoundKind.lineSignal);
      expect(AlarmKind.machine.level, AlertLevel.warning);
      for (final k in [AlarmKind.fire, AlarmKind.evacuation, AlarmKind.siren]) {
        expect(k.level, AlertLevel.critical);
      }
    });

    test('evacuation has its own icon', () {
      expect(AlarmKind.evacuation.icon, Icons.directions_run);
    });
  });

  test('toSoundAlert builds a labelled critical alert', () {
    final alert = toSoundAlert(AppLocalizationsRo(), alarmAt(44.0));
    expect(alert.label, 'Incendiu · semnalat de un coleg');
    expect(alert.kind, SoundKind.fireAlarm);
    expect(alert.level, AlertLevel.critical);
  });

  group('Alarm.fromJson', () {
    final good = {'id': 'x', 'kind': 'siren', 'at': 1760000000.5, 'lat': 44.0, 'lon': 26.0, 'accuracy_m': 12};

    test('parses epoch seconds', () {
      final a = Alarm.fromJson(good)!;
      expect(a.kind, AlarmKind.siren);
      expect(a.at, DateTime.fromMillisecondsSinceEpoch(1760000000500));
      expect(a.accuracyM, 12);
    });

    test('unknown kind or bad fields give null', () {
      expect(Alarm.fromJson({...good, 'kind': 'flood'}), isNull);
      expect(Alarm.fromJson({...good}..remove('lat')), isNull);
      expect(Alarm.fromJson({...good, 'id': 5}), isNull);
    });
  });
}
