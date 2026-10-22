import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../l10n/app_localizations.dart';
import '../alerts/alert_controller.dart';
import '../alerts/alert_overlay.dart';
import '../alerts/location_sounds.dart';
import '../alerts/sound_alert.dart';
import 'learn_sound_screen.dart';

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
          if (services.locationSounds != null) ...[
            const SizedBox(height: 32),
            _LocationSounds(store: services.locationSounds!),
          ],
        ],
      ),
    );
  }
}

/// Sounds learned here and sounds from the company. Admins can share what they learned.
class _LocationSounds extends StatelessWidget {
  const _LocationSounds({required this.store});
  final LocationSoundStore store;

  static String levelText(AppLocalizations l10n, AlertLevel level) => switch (level) {
        AlertLevel.critical => l10n.levelCritical,
        AlertLevel.warning => l10n.levelWarning,
        AlertLevel.info => l10n.levelInfo,
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
