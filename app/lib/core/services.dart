import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../features/alerts/alert_signals.dart';
import '../features/alerts/location_sounds.dart';
import '../features/alerts/sound_alert.dart';
import '../settings/app_settings.dart';
import 'server_api.dart';
import 'session_connection.dart';
import 'speech/speech_service.dart';

/// App-wide services. Tests swap in fakes through [ServicesScope].
class AppServices {
  AppServices({
    required this.speech,
    required this.sounds,
    this.alertSignals = const BasicAlertSignals(),
    this.locationSounds,
    this.httpClient,
    this.channelFactory,
  });

  final SpeechService speech;
  final SoundDetector sounds;

  /// Vibration patterns and system notifications for alerts, per platform.
  final AlertSignals alertSignals;

  /// Sounds learned on site; null where sound recognition cannot run.
  final LocationSoundStore? locationSounds;
  final http.Client? httpClient;
  final ChannelFactory? channelFactory;

  ServerApi api(Uri server) => ServerApi(server, client: httpClient);
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
