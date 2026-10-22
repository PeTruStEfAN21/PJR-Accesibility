import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/join_link.dart';
import 'core/services.dart';
import 'features/alerts/alert_controller.dart';
import 'features/alerts/alert_overlay.dart';
import 'features/alerts/sound_alert.dart';
import 'features/home/home_screen.dart';
import 'features/participant/participant_screen.dart';
import 'l10n/app_localizations.dart';
import 'settings/app_settings.dart';
import 'theme/app_theme.dart';

class EchoApp extends StatefulWidget {
  const EchoApp({super.key, required this.settings, required this.services, this.alerts});

  final AppSettings settings;
  final AppServices services;
  final AlertController? alerts;

  @override
  State<EchoApp> createState() => _EchoAppState();
}

class _EchoAppState extends State<EchoApp> {
  late final AlertController _alerts = widget.alerts ?? AlertController(haptic: widget.services.alertSignals.vibrate, hapticFor: widget.settings.hapticFor);
  StreamSubscription<SoundAlert>? _sounds;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Detected sounds reach the overlay whatever screen is open.
    _sounds = widget.services.sounds.alerts.listen(_alerts.show);
    _lifecycle = AppLifecycleListener(onResume: widget.services.soundListening.resumed);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _sounds?.cancel();
    if (widget.alerts == null) _alerts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ServicesScope(
      services: widget.services,
      child: SettingsScope(
        settings: widget.settings,
        child: AlertScope(
          controller: _alerts,
          child: ListenableBuilder(
            listenable: widget.settings,
            builder: (context, _) {
              final settings = widget.settings;
              return MaterialApp(
                onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
                debugShowCheckedModeBanner: false,
                locale: settings.locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                theme: buildTheme(settings),
                builder: (context, child) {
                  // The user's text size multiplies the system setting instead of replacing it.
                  final system = MediaQuery.textScalerOf(context).scale(1);
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(system * settings.textScale)),
                    child: AlertOverlay(signals: widget.services.alertSignals, child: child!),
                  );
                },
                home: _initialScreen(),
              );
            },
          ),
        ),
      ),
    );
  }

  /// The QR link opened in a browser (`/?code=ABC123`) goes straight to the captions.
  Widget _initialScreen() {
    if (kIsWeb) {
      final link = JoinLink.parse(Uri.base.toString());
      if (link != null) return ParticipantScreen(link: link);
    }
    return const HomeScreen();
  }
}
