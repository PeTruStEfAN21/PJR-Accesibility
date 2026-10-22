import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../features/alerts/alert_signals.dart';
import '../features/alerts/location_sounds.dart';
import '../features/alerts/sound_alert.dart';
import '../features/alerts/sound_listening.dart';
import '../features/emergency/position_source.dart';
import '../settings/app_settings.dart';
import 'account/account_service.dart';
import 'history/meeting_store.dart';
import 'server_api.dart';
import 'session_connection.dart';
import 'speech/speech_service.dart';
import 'tts/tts_service.dart';
import 'voice/voice_engine.dart';

/// App-wide services. Tests swap in fakes through [ServicesScope].
class AppServices {
  AppServices({
    required this.speech,
    required this.sounds,
    TtsService? tts,
    VoiceEngine? voice,
    SoundListening? soundListening,
    this.alertSignals = const BasicAlertSignals(),
    this.locationSounds,
    this.httpClient,
    this.channelFactory,
    this.account,
    this.meetings,
    this.positions = const GeolocatorPositionSource(),
  })  : tts = tts ?? createTtsService(),
        voice = voice ?? createVoiceEngine(),
        soundListening = soundListening ?? SoundListening(sounds);

  final SpeechService speech;
  final SoundDetector sounds;

  /// Reads the participant's question out loud on the presenter's laptop.
  final TtsService tts;

  /// Microphone and speaker model on the presenter's laptop: who is talking, the speaker or the room.
  final VoiceEngine voice;

  /// Whether sound recognition should run (remembered) and is running; paused while captions run.
  final SoundListening soundListening;

  /// Vibration patterns and system notifications for alerts, per platform.
  final AlertSignals alertSignals;

  /// Sounds learned on site; null where sound recognition cannot run.
  final LocationSoundStore? locationSounds;
  final http.Client? httpClient;
  final ChannelFactory? channelFactory;

  /// Null when accounts are off (no Supabase configured): no sign-in, nothing saved.
  final AccountService? account;
  final MeetingStore? meetings;

  /// Where this phone is, for colleague alarms. Constructing the default touches no plugin.
  final PositionSource positions;

  /// The meeting store, only while someone is signed in.
  MeetingStore? get signedInMeetings => (account?.isSignedIn ?? false) ? meetings : null;

  ServerApi api(Uri server) => ServerApi(server, client: httpClient, accessToken: () => account?.accessToken);
}

class ServicesScope extends InheritedWidget {
  const ServicesScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ServicesScope>()!.services;

  @override
  bool updateShouldNotify(ServicesScope oldWidget) => services != oldWidget.services;
}

const _devServer = 'http://localhost:8000';

/// Where the server is: the saved address, else the page's own origin when the
/// presenter page is served by the server itself, else localhost.
Uri defaultServer(AppSettings settings) {
  final saved = Uri.tryParse(settings.serverUrl.trim());
  if (saved != null && saved.hasScheme && saved.host.isNotEmpty) return saved;
  if (kIsWeb && Uri.base.port == 8000) {
    return Uri(scheme: Uri.base.scheme, host: Uri.base.host, port: Uri.base.port);
  }
  return Uri.parse(_devServer);
}
