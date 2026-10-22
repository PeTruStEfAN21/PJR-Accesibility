import 'package:flutter/services.dart';

import 'alert_controller.dart';
import 'alert_signals_stub.dart'
    if (dart.library.js_interop) 'alert_signals_web.dart'
    if (dart.library.ffi) 'alert_signals_native.dart' as platform;
import 'sound_alert.dart';

/// What makes an alert felt outside the app's own screen: vibration patterns and
/// system notifications (which also reach a paired watch), by severity.
abstract class AlertSignals {
  /// Asks for notification permission; call it from a user action (the browser requires it).
  Future<void> requestPermission();
  void vibrate(Haptic haptic);
  void notify(SoundAlert alert, String title, String body);
  void clear();
}

AlertSignals createAlertSignals() => platform.createAlertSignals();

/// Only the built-in haptics; used in tests and where nothing better exists.
class BasicAlertSignals implements AlertSignals {
  const BasicAlertSignals();

  @override
  Future<void> requestPermission() async {}

  @override
  void vibrate(Haptic haptic) {
    switch (haptic) {
      case Haptic.long:
        HapticFeedback.vibrate();
      case Haptic.strong:
        HapticFeedback.heavyImpact();
      case Haptic.light:
        HapticFeedback.lightImpact();
    }
  }

  @override
  void notify(SoundAlert alert, String title, String body) {}

  @override
  void clear() {}
}
