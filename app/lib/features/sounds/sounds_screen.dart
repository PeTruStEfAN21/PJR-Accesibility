import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../../theme/echo_style.dart';
import '../alerts/alert_controller.dart';
import '../alerts/alert_overlay.dart';
import '../alerts/location_sounds.dart';
import '../alerts/sound_alert.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/large_title.dart';
import 'learn_sound_screen.dart';
import 'vibration_picker.dart';

/// Explains sound alerts, turns "always listen" on or off and picks each level's vibration.
/// Listening keeps running after leaving this screen; alerts are shown app-wide by AlertOverlay,
/// over whatever screen is open.
/// "Sunetele locației" (learning the sounds of a place) is hidden for now; the feature is unchanged.
/// Tests of the feature turn it on.
var showLocationSounds = false;

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
      appBar: backBarIfPushed(context, l10n.soundsTitle),
      body: SafeArea(
        bottom: false,
        child: ListView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          LargeTitle(l10n.soundsTitle),
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
                  leading: RowIcon(levelIcon(level)),
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
                  leading: RowIcon(soundIcon(kind)),
                  title: soundLabel(l10n, kind),
                  onTap: () => alerts.show(SoundAlert(kind, at: DateTime.now())),
                ),
            ],
          ),
          if (services.locationSounds != null && showLocationSounds) ...[
            const SizedBox(height: 32),
            _LocationSounds(store: services.locationSounds!),
          ],
        ],
        ),
      ),
    );
  }
}

/// Sounds learned here and sounds from the company. Admins can share what they learned.
class _LocationSounds extends StatelessWidget {
  const _LocationSounds({required this.store});
  final LocationSoundStore store;

  static String levelText(AppLocalizations l10n, AlertLevel level) => switch (level) {
        AlertLevel.critical => l10n.learnLevelCritical,
        AlertLevel.warning => l10n.learnLevelWarning,
        AlertLevel.info => l10n.learnLevelInfo,
      };

  Future<void> _share(BuildContext context, LocationSound sound) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final organizations = ServicesScope.of(context).organizations!;
    try {
      for (final m in organizations.memberships.where((m) => m.isAdmin)) {
        await organizations.store.shareSound(m.orgId, sound, organizations.model);
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.locSoundsShared)));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.orgError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final organizations = ServicesScope.of(context).organizations;
    return ListenableBuilder(
      listenable: Listenable.merge([store, ?organizations]),
      builder: (context, _) {
        final canShare = organizations?.memberships.any((m) => m.isAdmin) ?? false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: Text(l10n.locSoundsTitle, style: theme.textTheme.titleLarge)),
            const SizedBox(height: 4),
            Text(l10n.locSoundsHint, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            if (store.sounds.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(l10n.locSoundsEmpty)),
            for (final sound in store.learned)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.graphic_eq),
                title: Text(sound.label),
                subtitle: Text(levelText(l10n, sound.level)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canShare)
                      IconButton(
                        tooltip: l10n.locSoundsShare,
                        icon: const Icon(Icons.ios_share),
                        onPressed: () => _share(context, sound),
                      ),
                    IconButton(
                      tooltip: l10n.locSoundsDelete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => store.remove(sound.id),
                    ),
                  ],
                ),
              ),
            for (final sound in store.shared)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.business),
                title: Text(sound.label),
                subtitle: Text('${l10n.locSoundsFromCompany} · ${levelText(l10n, sound.level)}'),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LearnSoundScreen())),
              icon: const Icon(Icons.add),
              label: Text(l10n.locSoundsLearn),
            ),
          ],
        );
      },
    );
  }
}
