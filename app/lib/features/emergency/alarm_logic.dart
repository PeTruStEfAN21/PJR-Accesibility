import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../alerts/alert_overlay.dart';
import '../alerts/sound_alert.dart';

/// The kinds of danger a colleague can raise by hand.
enum AlarmKind {
  fire,
  evacuation,
  siren,
  machine;

  /// The name used on the wire.
  String get wire => name;

  static AlarmKind? fromWire(String value) {
    for (final kind in values) {
      if (kind.wire == value) return kind;
    }
    return null;
  }

  AlertLevel get level => this == machine ? AlertLevel.warning : AlertLevel.critical;

  SoundKind get sound => switch (this) {
        fire => SoundKind.fireAlarm,
        evacuation => SoundKind.location,
        siren => SoundKind.siren,
        machine => SoundKind.lineSignal,
      };

  IconData get icon => this == evacuation ? Icons.directions_run : soundIcon(sound);
}

/// An alarm raised by a colleague, with the place it was raised from.
class Alarm {
  const Alarm({
    required this.id,
    required this.kind,
    required this.at,
    required this.lat,
    required this.lon,
    required this.accuracyM,
  });

  final String id;
  final AlarmKind kind;
  final DateTime at;
  final double lat;
  final double lon;
  final double accuracyM;

  /// Null for an unknown kind or a missing / ill-typed field. `at` is epoch seconds.
  static Alarm? fromJson(Map json) {
    final id = json['id'];
    final kind = json['kind'];
    final at = json['at'];
    final lat = json['lat'];
    final lon = json['lon'];
    final accuracy = json['accuracy_m'];
    if (id is! String || kind is! String || at is! num || lat is! num || lon is! num || accuracy is! num) {
      return null;
    }
    final parsed = AlarmKind.fromWire(kind);
    if (parsed == null) return null;
    return Alarm(
      id: id,
      kind: parsed,
      at: DateTime.fromMillisecondsSinceEpoch((at * 1000).round()),
      lat: lat.toDouble(),
      lon: lon.toDouble(),
      accuracyM: accuracy.toDouble(),
    );
  }
}

/// A position fix of this phone.
class Position {
  const Position({required this.lat, required this.lon, required this.accuracyM});
  final double lat;
  final double lon;
  final double accuracyM;
}

/// Great-circle distance in metres (haversine).
double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const radius = 6371000.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * radius * math.asin(math.min(1.0, math.sqrt(a)));
}

/// Within 500 m, widened by the fix accuracy (at most 100 m). Without a fix, everyone is in range.
bool inRange(Alarm alarm, Position? here) {
  if (here == null) return true;
  final limit = 500 + math.min(here.accuracyM, 100);
  return distanceMeters(alarm.lat, alarm.lon, here.lat, here.lon) <= limit;
}

String alarmName(AppLocalizations l10n, AlarmKind kind) => switch (kind) {
      AlarmKind.fire => l10n.alarmFire,
      AlarmKind.evacuation => l10n.alarmEvacuation,
      AlarmKind.siren => l10n.alarmSiren,
      AlarmKind.machine => l10n.alarmMachine,
    };

SoundAlert toSoundAlert(AppLocalizations l10n, Alarm alarm) => SoundAlert(
      alarm.kind.sound,
      at: alarm.at,
      label: l10n.alarmFromColleague(alarmName(l10n, alarm.kind)),
      level: alarm.kind.level,
    );
