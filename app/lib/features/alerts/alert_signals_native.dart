import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

import 'alert_controller.dart';
import 'alert_signals.dart';
import 'sound_alert.dart';

AlertSignals createAlertSignals() =>
    Platform.isIOS || Platform.isAndroid ? _MobileAlertSignals() : const BasicAlertSignals();

/// iPhone / Android: strong vibration patterns and alarm-style notifications.
/// Notifications are what reach Apple Watch / Wear OS (when the phone is locked or in a pocket).
class _MobileAlertSignals implements AlertSignals {
  _MobileAlertSignals() {
    _ready = _plugin
        .initialize(
          settings: const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestSoundPermission: false,
              requestBadgePermission: false,
            ),
          ),
        )
        .then((_) {}, onError: (Object e) => debugPrint('Notifications unavailable: $e'));
  }

  final _plugin = FlutterLocalNotificationsPlugin();
  late final Future<void> _ready;
  static const _id = 1;
  static const _fallback = BasicAlertSignals();

  @override
  Future<void> requestPermission() async {
    await _ready;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true, badge: false);
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await android?.requestFullScreenIntentPermission();
    } catch (e) {
      debugPrint('Notification permission failed: $e');
    }
  }

  @override
  void vibrate(Haptic haptic) {
    // Vibration.vibrate drives Core Haptics on iPhone and the vibrator on Android;
    // the built-in haptics stay as a fallback.
    final future = switch (haptic) {
      Haptic.long => Vibration.vibrate(duration: 450, amplitude: 255),
      Haptic.strong => Vibration.vibrate(pattern: [0, 400, 150, 400, 150, 400], intensities: [0, 255, 0, 255, 0, 255]),
      Haptic.light => Vibration.vibrate(duration: 150, amplitude: 128),
    };
    future.catchError((Object _) => _fallback.vibrate(haptic));
  }

  @override
  void notify(SoundAlert alert, String title, String body) {
    final critical = alert.level == AlertLevel.critical;
    final foreground = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    // On screen the overlay already shows it; a critical alert is also pushed so it reaches a watch.
    if (foreground && !critical) return;
    _show(alert.level, title, body);
  }

  Future<void> _show(AlertLevel level, String title, String body) async {
    await _ready;
    final details = switch (level) {
      AlertLevel.critical => NotificationDetails(
          android: AndroidNotificationDetails(
            'echo_critical',
            title,
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            fullScreenIntent: true,
            ongoing: true,
            autoCancel: false,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            vibrationPattern: Int64List.fromList([0, 1000, 400, 1000, 400, 1000, 400, 1000, 400, 1000]),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
      AlertLevel.warning => NotificationDetails(
          android: AndroidNotificationDetails(
            'echo_warning',
            title,
            importance: Importance.high,
            priority: Priority.high,
            vibrationPattern: Int64List.fromList([0, 400, 150, 400, 150, 400]),
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
      AlertLevel.info => const NotificationDetails(
          android: AndroidNotificationDetails('echo_info', 'Echo'),
          iOS: DarwinNotificationDetails(presentBanner: true, interruptionLevel: InterruptionLevel.active),
        ),
    };
    try {
      await _plugin.show(id: _id, title: title, body: body, notificationDetails: details);
    } catch (e) {
      debugPrint('Notification failed: $e');
    }
  }

  @override
  void clear() {
    Vibration.cancel().catchError((Object _) {});
    _ready.then((_) => _plugin.cancel(id: _id)).catchError((Object _) {});
  }
}
