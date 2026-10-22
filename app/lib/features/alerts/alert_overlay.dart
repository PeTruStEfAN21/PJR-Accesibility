import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import 'alert_controller.dart';
import 'sound_alert.dart';

String soundLabel(AppLocalizations l10n, SoundKind kind) => switch (kind) {
      SoundKind.fireAlarm => l10n.soundFireAlarm,
      SoundKind.siren => l10n.soundSiren,
      SoundKind.horn => l10n.soundHorn,
      SoundKind.lineSignal => l10n.soundLineSignal,
      SoundKind.name => l10n.soundName,
      SoundKind.phone => l10n.soundPhone,
      SoundKind.door => l10n.soundDoor,
    };

IconData soundIcon(SoundKind kind) => switch (kind) {
      SoundKind.fireAlarm => Icons.local_fire_department,
      SoundKind.siren => Icons.campaign,
      SoundKind.horn => Icons.forklift,
      SoundKind.lineSignal => Icons.precision_manufacturing,
      SoundKind.name => Icons.record_voice_over,
      SoundKind.phone => Icons.phone_in_talk,
      SoundKind.door => Icons.doorbell,
    };

/// Sits above every screen (MaterialApp.builder) so an alert is never hidden.
class AlertOverlay extends StatefulWidget {
  const AlertOverlay({super.key, required this.child});
  final Widget child;

  @override
  State<AlertOverlay> createState() => _AlertOverlayState();
}

class _AlertOverlayState extends State<AlertOverlay> {
  SoundAlert? _announced;

  @override
  Widget build(BuildContext context) {
    final controller = AlertScope.of(context);
    final alert = controller.current;
    final l10n = AppLocalizations.of(context);

    if (alert != null && !identical(alert, _announced)) {
      _announced = alert;
      // Screen readers announce the alert even if focus is elsewhere.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SemanticsService.sendAnnouncement(View.of(context), soundLabel(l10n, alert.kind), Directionality.of(context));
      });
    }

    return Stack(
      children: [
        // While a critical alert is up, the screen below is hidden from screen readers too.
        ExcludeSemantics(excluding: alert?.level == AlertLevel.critical, child: widget.child),
        if (alert != null)
          switch (alert.level) {
            AlertLevel.critical => _CriticalAlert(alert: alert, onDismiss: controller.dismiss),
            _ => _BannerAlert(alert: alert, onDismiss: controller.dismiss),
          },
      ],
    );
  }
}

class _CriticalAlert extends StatelessWidget {
  const _CriticalAlert({required this.alert, required this.onDismiss});
  final SoundAlert alert;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final exit = SettingsScope.of(context).emergencyExit.trim();
    const foreground = Colors.white;
    return Positioned.fill(
      child: Material(
        color: const Color(0xFFB00000),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(soundIcon(alert.kind), size: 120, color: foreground),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(
                    soundLabel(l10n, alert.kind),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(color: foreground, fontWeight: FontWeight.w800),
                  ),
                ),
                if (exit.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.alertExit(exit),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: foreground),
                  ),
                ],
                const SizedBox(height: 48),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: foreground,
                    foregroundColor: const Color(0xFFB00000),
                    minimumSize: const Size.fromHeight(64),
                    textStyle: Theme.of(context).textTheme.titleLarge,
                  ),
                  onPressed: onDismiss,
                  child: Text(l10n.alertDismiss),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerAlert extends StatelessWidget {
  const _BannerAlert({required this.alert, required this.onDismiss});
  final SoundAlert alert;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final warning = alert.level == AlertLevel.warning;
    final background = warning ? const Color(0xFFFFC233) : Theme.of(context).colorScheme.inverseSurface;
    final foreground = warning ? Colors.black : Theme.of(context).colorScheme.onInverseSurface;
    return Positioned(
      left: 0,
      right: 0,
      top: warning ? 0 : null,
      bottom: warning ? null : 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Semantics(
            liveRegion: true,
            child: Material(
              color: background,
              elevation: 6,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(soundIcon(alert.kind), size: warning ? 40 : 28, color: foreground),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        soundLabel(l10n, alert.kind),
                        style: (warning
                                ? Theme.of(context).textTheme.titleLarge
                                : Theme.of(context).textTheme.titleMedium)
                            ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.close,
                      onPressed: onDismiss,
                      icon: Icon(Icons.close, color: foreground),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
