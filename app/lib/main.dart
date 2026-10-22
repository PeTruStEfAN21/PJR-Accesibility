import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/account/account_service.dart';
import 'core/account/supabase_config.dart';
import 'core/history/meeting_store.dart';
import 'core/org/org_store.dart';
import 'core/org/organizations.dart';
import 'core/services.dart';
import 'core/speech/mic_sharing_speech.dart';
import 'core/speech/speech_service.dart';
import 'features/alerts/alert_signals.dart';
import 'features/alerts/location_sounds.dart';
import 'features/alerts/sound_alert.dart';
import 'features/alerts/sound_listening.dart';
import 'features/alerts/yamnet_detector.dart';
import 'features/alerts/yamnet_model.dart';
import 'settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs);

  // Accounts are optional: without SUPABASE_URL / SUPABASE_ANON_KEY nothing is signed in or saved.
  AccountService? account;
  MeetingStore? meetings;
  OrgStore? orgStore;
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.anonKey);
    final client = Supabase.instance.client;
    account = SupabaseAccountService(client);
    meetings = SupabaseMeetingStore(client);
    orgStore = SupabaseOrgStore(client);
  }

  // YAMNet runs on the device: TFLite on iPhone / Android, TensorFlow.js in the browser.
  final model = createYamnetModel();
  final locationSounds = model.isSupported ? LocationSoundStore(prefs) : null;
  final signals = createAlertSignals();
  final SoundDetector sounds = locationSounds != null
      ? YamnetSoundDetector(model: model, locationSounds: locationSounds, signals: signals)
      : UnavailableSoundDetector();
  // Once turned on, listening runs on every launch; captions pause it while they use the microphone.
  final listening = SoundListening(
    sounds,
    wanted: prefs.getBool(_alwaysListenKey) ?? false,
    onWantedChanged: (on) => prefs.setBool(_alwaysListenKey, on),
  );
  // Companies of the signed-in user; their shared sounds join the detector's list.
  final organizations = account != null && orgStore != null
      ? (Organizations(
          store: orgStore,
          account: account,
          sounds: locationSounds,
          model: kIsWeb ? SoundModel.tfjs : SoundModel.tflite,
        )..refresh())
      : null;
  final services = AppServices(
    speech: MicSharingSpeech(PlatformSpeechService(), takeMic: listening.hold, giveBackMic: listening.release),
    sounds: sounds,
    soundListening: listening,
    alertSignals: signals,
    locationSounds: locationSounds,
    account: account,
    meetings: meetings,
    organizations: organizations,
  );
  runApp(EchoApp(settings: settings, services: services));
  listening.autoStart();
}

const _alwaysListenKey = 'alwaysListen';
