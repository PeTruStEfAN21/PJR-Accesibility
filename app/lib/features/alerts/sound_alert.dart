import 'dart:async';

enum AlertLevel { critical, warning, info }

/// Sounds the app reacts to. YAMNet (AudioSet classes) is mapped onto these.
enum SoundKind {
  fireAlarm(AlertLevel.critical),
  siren(AlertLevel.critical),
  horn(AlertLevel.warning),
  lineSignal(AlertLevel.warning),
  name(AlertLevel.info),
  phone(AlertLevel.info),
  door(AlertLevel.info);

  const SoundKind(this.level);
  final AlertLevel level;
}

class SoundAlert {
  const SoundAlert(this.kind, {required this.at, this.confidence = 1});
  final SoundKind kind;
  final DateTime at;
  final double confidence;

  AlertLevel get level => kind.level;
}

/// Listens to the microphone and reports recognised sounds, entirely on the device.
abstract class SoundDetector {
  bool get isAvailable;
  Stream<SoundAlert> get alerts;
  Future<bool> start();
  Future<void> stop();
  void dispose();
}

/// Placeholder until the YAMNet detector exists (see the demo plan, person 3).
class UnavailableSoundDetector implements SoundDetector {
  final _alerts = StreamController<SoundAlert>.broadcast();

  @override
  bool get isAvailable => false;

  @override
  Stream<SoundAlert> get alerts => _alerts.stream;

  @override
  Future<bool> start() async => false;

  @override
  Future<void> stop() async {}

  @override
  void dispose() => _alerts.close();
}
