import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../../theme/echo_style.dart';
import '../alerts/alert_controller.dart';
import '../alerts/alert_overlay.dart';
import '../alerts/sound_alert.dart';
import 'grouped_list.dart';
import 'vibration_picker.dart';

/// Explains sound alerts, turns "always listen" on or off and picks each level's vibration.
/// Listening keeps running after leaving this screen; alerts are shown app-wide by AlertOverlay,
/// over whatever screen is open.
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
    final palette = EchoPalette.of(context);
    final settings = SettingsScope.of(context);
    final detector = services.sounds;
    final listening = services.soundListening;
    final alerts = AlertScope.of(context);
    final status = listening.paused
        ? l10n.soundsPaused
        : listening.listening
            ? l10n.soundsListening
            : l10n.soundsIdle;
    // At large text the vibration's name moves under the examples, so the level keeps its width.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    String examples(AlertLevel level) => switch (level) {
          AlertLevel.critical => l10n.soundsLevelExamplesCritical,
          AlertLevel.warning => l10n.soundsLevelExamplesWarning,
          AlertLevel.info => l10n.soundsLevelExamplesInfo,
        };

    return Scaffold(
      backgroundColor: palette.ground,
      appBar: AppBar(
        backgroundColor: palette.ground,
        foregroundColor: palette.text,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(l10n.soundsTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(l10n.soundsExplain, style: theme.textTheme.bodyLarge?.copyWith(color: palette.text)),
          ),
          const SizedBox(height: 24),
          EchoGroup(
            rows: [
              SwitchListTile(
                value: detector.isAvailable && listening.wanted,
                onChanged: detector.isAvailable ? (on) => on ? listening.enable() : listening.disable() : null,
                activeTrackColor: palette.accent,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Text(l10n.soundsSwitch, style: theme.textTheme.titleMedium?.copyWith(color: palette.text, fontWeight: FontWeight.w500)),
                subtitle: Semantics(
                  liveRegion: true,
                  child: Text(status, style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted)),
                ),
              ),
            ],
            footer: detector.isAvailable ? null : Text(l10n.soundsDetectorMissing),
          ),
          const SizedBox(height: 28),
          EchoGroup(
            title: l10n.soundsVibrations,
            rows: [
              for (final level in AlertLevel.values)
                EchoGroupRow(
                  key: ValueKey('level-${level.name}'),
                  leading: Icon(levelIcon(level), color: palette.text),
                  title: levelLabel(l10n, level),
                  subtitle: [examples(level), if (stacked) hapticName(l10n, settings.hapticFor(level))],
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!stacked)
                        Text(hapticName(l10n, settings.hapticFor(level)),
                            style: theme.textTheme.bodyLarge?.copyWith(color: palette.muted)),
                      Icon(Icons.chevron_right, color: palette.muted),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => VibrationPicker(level: level)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
          EchoGroup(
            title: l10n.soundsTest,
            rows: [
              for (final kind in [SoundKind.fireAlarm, SoundKind.horn, SoundKind.name])
                EchoGroupRow(
                  leading: Icon(soundIcon(kind), color: palette.text),
                  title: soundLabel(l10n, kind),
                  onTap: () => alerts.show(SoundAlert(kind, at: DateTime.now())),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
