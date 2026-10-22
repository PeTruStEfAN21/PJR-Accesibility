import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/account/account_service.dart';
import 'core/account/supabase_config.dart';
import 'core/history/meeting_store.dart';
import 'core/services.dart';
import 'core/speech/speech_service.dart';
import 'features/alerts/sound_alert.dart';
import 'settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings(await SharedPreferences.getInstance());

  AccountService? account;
  MeetingStore? meetings;
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.anonKey);
    final client = Supabase.instance.client;
    account = SupabaseAccountService(client);
    meetings = SupabaseMeetingStore(client);
  }

  final services = AppServices(
    speech: PlatformSpeechService(),
    // Replace with the YAMNet detector once it exists.
    sounds: UnavailableSoundDetector(),
    account: account,
    meetings: meetings,
  );
  runApp(EchoApp(settings: settings, services: services));
}
