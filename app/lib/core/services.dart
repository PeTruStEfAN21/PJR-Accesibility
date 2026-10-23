import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../features/alerts/alert_signals.dart';
import '../features/alerts/location_sounds.dart';
import '../features/alerts/sound_alert.dart';
import '../features/alerts/sound_listening.dart';
import '../features/coach/alert_window.dart';
import '../features/coach/coach_audio.dart';
import '../features/emergency/position_source.dart';
import '../settings/app_settings.dart';
import 'account/account_service.dart';
import 'history/meeting_store.dart';
import 'org/activity_store.dart';
import 'org/organizations.dart';
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
    CoachAudio? coachAudio,
    AlertWindow? alertWindow,
    SoundListening? soundListening,
    this.alertSignals = const BasicAlertSignals(),
    this.locationSounds,
    this.httpClient,
    this.channelFactory,
    this.account,
    this.meetings,
    this.organizations,
    this.activity,
    this.positions = const GeolocatorPositionSource(),
  })  : tts = tts ?? createTtsService(),
        voice = voice ?? createVoiceEngine(),
        coachAudio = coachAudio ?? createCoachAudio(),
        alertWindow = alertWindow ?? createAlertWindow(),
        soundListening = soundListening ?? SoundListening(sounds);

  final SpeechService speech;
  final SoundDetector sounds;

  /// Reads the participant's question out loud on the presenter's laptop.
  final TtsService tts;

  /// Microphone and speaker model on the presenter's laptop: who is talking, the speaker or the room.
  final VoiceEngine voice;

  /// The colleague's microphone for the clarity coach (online meetings), analysed in the page.
  final CoachAudio coachAudio;

  /// The coach's alert in a small window above the meeting app.
  final AlertWindow alertWindow;

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

  /// The signed-in user's companies; null when accounts are off.
  final Organizations? organizations;

  /// Everyone's own history and, for admins, the company's history and meetings; null when accounts are off.
  final ActivityStore? activity;

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

/// The server when nothing is saved; a build for a hosted server passes ECHO_SERVER.
const _devServer = String.fromEnvironment('ECHO_SERVER', defaultValue: 'http://localhost:8000');

/// Where the server is: the saved address, else the page's own origin when the
/// presenter page is served by the server itself, else the build's server.
Uri defaultServer(AppSettings settings) =>
    resolveServer(saved: settings.serverUrl, web: kIsWeb, page: Uri.base, fallback: Uri.parse(_devServer));

/// The server itself serves the page on port 8000 locally, and over HTTPS when hosted
/// (Render); `flutter run -d chrome` serves it on another port, without the server.
@visibleForTesting
Uri resolveServer({required String saved, required bool web, required Uri page, required Uri fallback}) {
  final savedUri = Uri.tryParse(saved.trim());
  if (savedUri != null && savedUri.hasScheme && savedUri.host.isNotEmpty) return savedUri;
  if (web && (page.port == 8000 || page.scheme == 'https')) {
    return Uri(scheme: page.scheme, host: page.host, port: page.port);
  }
  return fallback;
}
