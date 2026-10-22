import 'dart:js_interop';

import 'alert_controller.dart';
import 'alert_signals.dart';
import 'sound_alert.dart';

AlertSignals createAlertSignals() => _WebAlertSignals();

@JS('echoAlerts.permission')
external JSPromise<JSAny?> _permission();

@JS('echoAlerts.vibrate')
external void _vibrate(JSArray<JSNumber> pattern);

@JS('echoAlerts.notify')
external void _notify(String title, String body, bool critical);

@JS('echoAlerts.clear')
external void _clear();

/// Laptop / phone browser, through web/js/alerts.js: system notification (also when the tab
/// is in the background), a flashing tab title for critical alerts, and vibration where the
/// browser supports it (Chrome on Android).
class _WebAlertSignals implements AlertSignals {
  @override
  Future<void> requestPermission() async {
    try {
      await _permission().toDart;
    } catch (_) {}
  }

  @override
  void vibrate(Haptic haptic) {
    final pattern = switch (haptic) {
      Haptic.long => [450],
      Haptic.strong => [400, 150, 400, 150, 400],
      Haptic.light => [150],
    };
    _vibrate([for (final ms in pattern) ms.toJS].toJS);
  }

  @override
  void notify(SoundAlert alert, String title, String body) =>
      _notify(title, body, alert.level == AlertLevel.critical);

  @override
  void clear() => _clear();
}
