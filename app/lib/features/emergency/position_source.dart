import 'package:geolocator/geolocator.dart' as geo;

import 'alarm_logic.dart';

/// Where this phone is, when the user lets us know.
abstract class PositionSource {
  /// A fresh fix, or null when there is none within [timeout]. With [ask] false the
  /// permission is only checked, never asked for (no system prompt to wait behind).
  Future<Position?> current({Duration timeout = const Duration(seconds: 5), bool ask = true});

  /// The most recent fix the platform remembers, or null.
  Future<Position?> lastKnown({bool ask = true});
}

/// The platform's location, with permission asked "while using the app". Any error is null.
class GeolocatorPositionSource implements PositionSource {
  const GeolocatorPositionSource();

  @override
  Future<Position?> current({Duration timeout = const Duration(seconds: 5), bool ask = true}) async {
    try {
      if (!await _allowed(ask)) return null;
      final fix = await geo.Geolocator.getCurrentPosition(locationSettings: geo.LocationSettings(timeLimit: timeout))
          .timeout(timeout);
      return _from(fix);
    } on Object {
      return null;
    }
  }

  @override
  Future<Position?> lastKnown({bool ask = true}) async {
    try {
      if (!await _allowed(ask)) return null;
      final fix = await geo.Geolocator.getLastKnownPosition();
      return fix == null ? null : _from(fix);
    } on Object {
      return null;
    }
  }

  static Future<bool> _allowed(bool ask) async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) return false;
    var permission = await geo.Geolocator.checkPermission();
    if (ask && permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    return permission == geo.LocationPermission.whileInUse || permission == geo.LocationPermission.always;
  }

  static Position _from(geo.Position fix) =>
      Position(lat: fix.latitude, lon: fix.longitude, accuracyM: fix.accuracy);
}
