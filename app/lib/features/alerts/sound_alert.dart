import 'dart:async';
import 'dart:typed_data';

enum AlertLevel { critical, warning, info }

/// Sounds the app reacts to. YAMNet (AudioSet classes) is mapped onto these;
/// [location] is a sound learned on site, whose level the user picks.
enum SoundKind {
  fireAlarm(AlertLevel.critical),
  siren(AlertLevel.critical),
  horn(AlertLevel.warning),
  lineSignal(AlertLevel.warning),
  name(AlertLevel.info),
  phone(AlertLevel.info),
  door(AlertLevel.info),
  glassBreak(AlertLevel.warning),
  location(AlertLevel.warning);

  const SoundKind(this.level);
  final AlertLevel level;
}

class SoundAlert {
  const SoundAlert(this.kind, {required this.at, this.confidence = 1, this.label, AlertLevel? level}) : _level = level;
  final SoundKind kind;
  final DateTime at;
  final double confidence;

  /// The name of a learned sound ("Alarma halei 2"); null for the built-in kinds.
  final String? label;
  final AlertLevel? _level;

  AlertLevel get level => _level ?? kind.level;
}

/// Listens to the microphone and reports recognised sounds, entirely on the device.
abstract class SoundDetector {
  bool get isAvailable;
  Stream<SoundAlert> get alerts;
  Future<bool> start();
  Future<void> stop();

  /// Records [duration] of sound and returns its fingerprint for a learned sound,
  /// or null if the microphone or the model is not available.
  Future<Float32List?> recordSample(Duration duration);
  void dispose();
}

/// Used where YAMNet cannot run; the alerts can still be tried from the Sounds screen.
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
  Future<Float32List?> recordSample(Duration duration) async => null;

  @override
  void dispose() => _alerts.close();
}
