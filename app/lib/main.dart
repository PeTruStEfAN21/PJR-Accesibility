import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/services.dart';
import 'core/speech/speech_service.dart';
import 'features/alerts/sound_alert.dart';
import 'settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings(await SharedPreferences.getInstance());
  final services = AppServices(
    speech: PlatformSpeechService(),
    // Replace with the YAMNet detector once it exists.
    sounds: UnavailableSoundDetector(),
  );
  runApp(EchoApp(settings: settings, services: services));
}
