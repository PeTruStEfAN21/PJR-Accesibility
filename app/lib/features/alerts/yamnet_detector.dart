import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';

import 'alert_signals.dart';
import 'location_sounds.dart';
import 'sound_alert.dart';
import 'yamnet_logic.dart';
import 'yamnet_model.dart';

/// Microphone → YAMNet → alerts, entirely on the device (phone or laptop browser).
class YamnetSoundDetector implements SoundDetector {
  YamnetSoundDetector({
    required this.model,
    required this.locationSounds,
    this.signals = const BasicAlertSignals(),
    AudioRecorder? recorder,
  }) : _recorder = recorder ?? AudioRecorder();

  final YamnetModel model;
  final LocationSoundStore locationSounds;

  /// Asked for notification permission on start: it runs from the user's tap, which browsers require.
  final AlertSignals signals;
  final AudioRecorder _recorder;
  final _alerts = StreamController<SoundAlert>.broadcast();
  final _windower = PcmWindower();

  Future<SoundAnalyzer>? _ready;
  StreamSubscription<Uint8List>? _mic;
  bool _failed = false;
  bool _listening = false;
  bool _busy = false;
  Float32List? _pending;

  /// Under this loudness a learning sample counts as silence.
  static const _quietRms = 0.003;

  static const _config = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: yamnetSampleRate,
    numChannels: 1,
    // Alarms are exactly the "noise" these filters remove.
    autoGain: false,
    echoCancel: false,
    noiseSuppress: false,
    // Without this, iOS mutes vibration while the microphone records.
    iosConfig: IosRecordConfig(
      allowHapticsAndSystemSoundsDuringRecording: true,
      categoryOptions: [
        IosAudioCategoryOption.mixWithOthers,
        IosAudioCategoryOption.defaultToSpeaker,
        IosAudioCategoryOption.allowBluetooth,
      ],
    ),
    audioInterruption: AudioInterruptionMode.none,
  );

  @override
  bool get isAvailable => model.isSupported && !_failed;

  @override
  Stream<SoundAlert> get alerts => _alerts.stream;

  /// Loads the model and the class names; called early so the first start is quick.
  Future<SoundAnalyzer> prepare() => _ready ??= () async {
        try {
          final names = parseClassMap(await rootBundle.loadString('assets/models/yamnet_class_map.csv'));
          final head = DangerHead.fromJson(
            jsonDecode(await rootBundle.loadString(model.dangerHeadAsset)) as Map<String, dynamic>,
          );
          await model.load();
          return SoundAnalyzer(classes: mapYamnetClasses(names), locationSounds: () => locationSounds.sounds, head: head);
        } catch (e) {
          _failed = true;
          debugPrint('YAMNet unavailable: $e');
          rethrow;
        }
      }();

  @override
  Future<bool> start() async {
    if (_listening) return true;
    final SoundAnalyzer analyzer;
    try {
      analyzer = await prepare();
    } catch (_) {
      return false;
    }
    await signals.requestPermission();
    if (!await _recorder.hasPermission()) return false;
    analyzer.reset();
    _windower.reset();
    final stream = await _recorder.startStream(_config);
    _listening = true;
    _mic = stream.listen((bytes) {
      for (final window in _windower.add(bytes)) {
        _process(analyzer, window);
      }
    });
    return true;
  }

  /// One window at a time; if the model falls behind, only the newest window waits.
  Future<void> _process(SoundAnalyzer analyzer, Float32List window) async {
    if (_busy) {
      _pending = window;
      return;
    }
    _busy = true;
    try {
      Float32List? next = window;
      while (next != null) {
        _pending = null;
        final output = await model.run(next);
        if (!_listening) break;
        for (final alert in analyzer.analyze(output, DateTime.now())) {
          _alerts.add(alert);
        }
        next = _pending;
      }
    } catch (e) {
      debugPrint('YAMNet window failed: $e');
    } finally {
      _busy = false;
    }
  }

  @override
  Future<void> stop() async {
    _listening = false;
    await _mic?.cancel();
    _mic = null;
    if (await _recorder.isRecording()) await _recorder.stop();
  }

  @override
  Future<Float32List?> recordSample(Duration duration) async {
    final wasListening = _listening;
    try {
      await prepare();
      if (!await _recorder.hasPermission()) return null;
      await stop();

      final windower = PcmWindower();
      final windows = <Float32List>[];
      final stream = await _recorder.startStream(_config);
      final sub = stream.listen((bytes) => windows.addAll(windower.add(bytes)));
      await Future<void>.delayed(duration);
      await sub.cancel();
      await _recorder.stop();

      final loud = windows.where((w) => _rms(w) >= _quietRms).toList();
      if (loud.isEmpty) return null;
      final embeddings = [for (final w in loud) (await model.run(w)).embedding];
      return fingerprint(embeddings);
    } catch (e) {
      debugPrint('Learning sample failed: $e');
      return null;
    } finally {
      if (wasListening) await start();
    }
  }

  static double _rms(Float32List w) {
    if (w.isEmpty) return 0;
    var sum = 0.0;
    for (final v in w) {
      sum += v * v;
    }
    return math.sqrt(sum / w.length);
  }

  @override
  void dispose() {
    stop();
    _recorder.dispose();
    model.close();
    _alerts.close();
  }
}
