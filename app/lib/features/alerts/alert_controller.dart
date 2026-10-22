import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'sound_alert.dart';

enum Haptic { long, strong, light }

/// How long each vibration pattern lasts.
extension HapticTiming on Haptic {
  Duration get duration => switch (this) {
        Haptic.long => const Duration(milliseconds: 450),
        Haptic.strong => const Duration(milliseconds: 1500),
        Haptic.light => const Duration(milliseconds: 150),
      };
}

/// The vibration each alert level uses until the user picks another.
const defaultAlertHaptics = <AlertLevel, Haptic>{
  AlertLevel.critical: Haptic.long,
  AlertLevel.warning: Haptic.strong,
  AlertLevel.info: Haptic.light,
};

/// Decides which alert is on screen and drives the vibration pattern.
///
/// A critical alert is never replaced or auto-dismissed: the user has to
/// acknowledge it. Lower levels never hide a higher one.
class AlertController extends ChangeNotifier {
  AlertController({void Function(Haptic)? haptic}) : _haptic = haptic ?? _platformHaptic;

  static const warningDuration = Duration(seconds: 8);
  static const infoDuration = Duration(seconds: 4);
  static const _criticalPulse = Duration(milliseconds: 500);

  final void Function(Haptic) _haptic;
  SoundAlert? _current;
  Timer? _autoDismiss;
  Timer? _pulse;

  SoundAlert? get current => _current;

  void show(SoundAlert alert) {
    final current = _current;
    if (current != null && current.level.index < alert.level.index) return;

    _autoDismiss?.cancel();
    _pulse?.cancel();
    _current = alert;
    switch (alert.level) {
      case AlertLevel.critical:
        _haptic(Haptic.long);
        // iOS has no endless vibration API: keep pulsing until acknowledged.
        _pulse = Timer.periodic(_criticalPulse, (_) => _haptic(Haptic.long));
      case AlertLevel.warning:
        _haptic(Haptic.strong);
        _autoDismiss = Timer(warningDuration, dismiss);
      case AlertLevel.info:
        _haptic(Haptic.light);
        _autoDismiss = Timer(infoDuration, dismiss);
    }
    notifyListeners();
  }

  void dismiss() {
    _autoDismiss?.cancel();
    _pulse?.cancel();
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    _pulse?.cancel();
    super.dispose();
  }

  static void _platformHaptic(Haptic kind) {
    switch (kind) {
      case Haptic.long:
        HapticFeedback.vibrate();
      case Haptic.strong:
        HapticFeedback.heavyImpact();
      case Haptic.light:
        HapticFeedback.lightImpact();
    }
  }
}

class AlertScope extends InheritedNotifier<AlertController> {
  const AlertScope({super.key, required AlertController controller, required super.child})
      : super(notifier: controller);

  static AlertController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AlertScope>()!.notifier!;
}
