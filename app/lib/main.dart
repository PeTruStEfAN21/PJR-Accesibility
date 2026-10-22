import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/services.dart';
import 'core/speech/speech_service.dart';
import 'features/alerts/alert_signals.dart';
import 'features/alerts/location_sounds.dart';
import 'features/alerts/sound_alert.dart';
import 'features/alerts/yamnet_detector.dart';
import 'features/alerts/yamnet_model.dart';
import 'settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs);

  // YAMNet runs on the device: TFLite on iPhone / Android, TensorFlow.js in the browser.
  final model = createYamnetModel();
  final locationSounds = model.isSupported ? LocationSoundStore(prefs) : null;
  final signals = createAlertSignals();
  final services = AppServices(
    speech: PlatformSpeechService(),
    sounds: locationSounds != null
        ? YamnetSoundDetector(model: model, locationSounds: locationSounds, signals: signals)
        : UnavailableSoundDetector(),
    alertSignals: signals,
    locationSounds: locationSounds,
  );
  runApp(EchoApp(settings: settings, services: services));
}
