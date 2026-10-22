import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../l10n/app_localizations.dart';
import '../alerts/alert_controller.dart';
import '../alerts/alert_overlay.dart';
import '../alerts/sound_alert.dart';

/// Turns sound recognition on or off. Alerts themselves are shown app-wide by
/// AlertOverlay, so they appear over whatever screen is open.
class SoundsScreen extends StatefulWidget {
  const SoundsScreen({super.key});

  @override
  State<SoundsScreen> createState() => _SoundsScreenState();
}

class _SoundsScreenState extends State<SoundsScreen> {
  bool _listening = false;

  Future<void> _toggle() async {
    final detector = ServicesScope.of(context).sounds;
    if (_listening) {
      await detector.stop();
      setState(() => _listening = false);
    } else {
      final ok = await detector.start();
      setState(() => _listening = ok);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final detector = ServicesScope.of(context).sounds;
    final alerts = AlertScope.of(context);

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
          Icon(_listening ? Icons.hearing : Icons.hearing_disabled, size: 96, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              _listening ? l10n.soundsListening : l10n.soundsIdle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
            onPressed: detector.isAvailable ? _toggle : null,
            child: Text(_listening ? l10n.soundsStop : l10n.soundsStart),
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
