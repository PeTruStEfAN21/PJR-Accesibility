import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../l10n/app_localizations.dart';
import '../alerts/alert_controller.dart';
import '../alerts/alert_overlay.dart';
import '../alerts/sound_alert.dart';

/// Turns "always listen" on or off. Listening keeps running after leaving this
/// screen; alerts are shown app-wide by AlertOverlay, over whatever screen is open.
class SoundsScreen extends StatelessWidget {
  const SoundsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = ServicesScope.of(context);
    return ListenableBuilder(
      listenable: services.soundListening,
      builder: (context, _) => _build(context, services),
    );
  }

  Widget _build(BuildContext context, AppServices services) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final detector = services.sounds;
    final listening = services.soundListening;
    final alerts = AlertScope.of(context);
    final status = listening.paused
        ? l10n.soundsPaused
        : listening.listening
            ? l10n.soundsListening
            : l10n.soundsIdle;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.soundsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!detector.isAvailable)
            Card(
              child: ListTile(leading: const Icon(Icons.info_outline), title: Text(l10n.soundsDetectorMissing)),
            ),
          const SizedBox(height: 16),
          Icon(listening.wanted ? Icons.hearing : Icons.hearing_disabled, size: 96, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              status,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
            onPressed: detector.isAvailable ? (listening.wanted ? listening.disable : listening.enable) : null,
            child: Text(listening.wanted ? l10n.soundsStop : l10n.soundsStart),
          ),
          const SizedBox(height: 32),
          Semantics(header: true, child: Text(l10n.soundsTest, style: theme.textTheme.titleLarge)),
          const SizedBox(height: 8),
          for (final kind in [SoundKind.fireAlarm, SoundKind.horn, SoundKind.name])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: () => alerts.show(SoundAlert(kind, at: DateTime.now())),
                icon: Icon(soundIcon(kind)),
                label: Text(soundLabel(l10n, kind)),
              ),
            ),
        ],
      ),
    );
  }
}
