import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/services.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../../theme/echo_style.dart';
import '../alerts/alert_controller.dart';
import '../alerts/sound_alert.dart';
import '../../widgets/grouped_list.dart';

String hapticName(AppLocalizations l10n, Haptic haptic) => switch (haptic) {
      Haptic.long => l10n.hapticLong,
      Haptic.strong => l10n.hapticStrong,
      Haptic.light => l10n.hapticLight,
    };

String hapticDescription(AppLocalizations l10n, Haptic haptic) => switch (haptic) {
      Haptic.long => l10n.hapticLongHint,
      Haptic.strong => l10n.hapticStrongHint,
      Haptic.light => l10n.hapticLightHint,
    };

String levelLabel(AppLocalizations l10n, AlertLevel level) => switch (level) {
      AlertLevel.critical => l10n.levelCritical,
      AlertLevel.warning => l10n.levelWarning,
      AlertLevel.info => l10n.levelInfo,
    };

/// The same icons as the alert screens, so a level is never told by colour alone.
IconData levelIcon(AlertLevel level) => switch (level) {
      AlertLevel.critical => Icons.error_outline_rounded,
      AlertLevel.warning => Icons.warning_amber_rounded,
      AlertLevel.info => Icons.info_outline_rounded,
    };

/// Picks the vibration of one alert level, like picking a ringtone: a tap plays the vibration and
/// chooses it at once. Each level keeps a different vibration, so taking another level's swaps them.
class VibrationPicker extends StatelessWidget {
  const VibrationPicker({super.key, required this.level});

  final AlertLevel level;

  void _choose(BuildContext context, Haptic haptic) {
    // One play only, through the same call real alerts use; never clear(), which would drop notifications.
    ServicesScope.of(context).alertSignals.vibrate(haptic);
    final settings = SettingsScope.of(context);
    final other = settings.chooseHaptic(level, haptic);
    if (other == null) return;
    final l10n = AppLocalizations.of(context);
    final message = l10n.vibrationSwapped(levelLabel(l10n, other), hapticName(l10n, settings.hapticFor(other)));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = EchoPalette.of(context);
    final settings = SettingsScope.of(context);
    final chosen = settings.hapticFor(level);

    return Scaffold(
      backgroundColor: palette.ground,
      appBar: AppBar(
        backgroundColor: palette.ground,
        foregroundColor: palette.text,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(levelLabel(l10n, level)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          EchoGroup(
            title: l10n.soundsVibrations,
            rows: [
              for (final haptic in Haptic.values)
                EchoGroupRow(
                  key: ValueKey('haptic-${haptic.name}'),
                  selected: haptic == chosen,
                  // The tick sits first, where iOS puts it, in a fixed slot so the names line up.
                  leading: SizedBox(
                    width: 24,
                    child: haptic == chosen ? Icon(Icons.check, color: palette.accent) : null,
                  ),
                  title: hapticName(l10n, haptic),
                  subtitle: [
                    hapticDescription(l10n, haptic),
                    for (final other in AlertLevel.values)
                      if (other != level && settings.hapticFor(other) == haptic) l10n.vibrationUsedBy(levelLabel(l10n, other)),
                  ],
                  onTap: () => _choose(context, haptic),
                ),
            ],
            footer: level == AlertLevel.critical ? Text(l10n.vibrationCriticalRepeats) : null,
          ),
        ],
      ),
    );
  }
}
