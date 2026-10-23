import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../core/org/org_store.dart';
import '../../core/services.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../../theme/echo_style.dart';
import '../../widgets/glass.dart';
import '../../widgets/grouped_list.dart';
import '../sounds/vibration_picker.dart';
import 'alert_controller.dart';
import 'alert_signals.dart';
import 'sound_alert.dart';

String soundLabel(AppLocalizations l10n, SoundKind kind) => switch (kind) {
      SoundKind.fireAlarm => l10n.soundFireAlarm,
      SoundKind.siren => l10n.soundSiren,
      SoundKind.horn => l10n.soundHorn,
      SoundKind.lineSignal => l10n.soundLineSignal,
      SoundKind.name => l10n.soundName,
      SoundKind.phone => l10n.soundPhone,
      SoundKind.door => l10n.soundDoor,
      SoundKind.glassBreak => l10n.soundGlassBreak,
      SoundKind.location => l10n.soundLocation,
    };

/// A learned sound shows its own name ("Alarma halei 2").
String alertLabel(AppLocalizations l10n, SoundAlert alert) => alert.label ?? soundLabel(l10n, alert.kind);

IconData soundIcon(SoundKind kind) => switch (kind) {
      SoundKind.fireAlarm => Icons.local_fire_department_outlined,
      SoundKind.siren => Icons.campaign_outlined,
      SoundKind.horn => Icons.directions_car_outlined,
      SoundKind.lineSignal => Icons.precision_manufacturing_outlined,
      SoundKind.name => Icons.record_voice_over_outlined,
      SoundKind.phone => Icons.phone_in_talk_outlined,
      SoundKind.door => Icons.doorbell_outlined,
      SoundKind.glassBreak => Icons.broken_image_outlined,
      SoundKind.location => Icons.graphic_eq,
    };

/// What to do, for the sounds that cover the screen; null where the name says enough.
String? alertAdvice(AppLocalizations l10n, SoundAlert alert) => switch (alert.kind) {
      SoundKind.fireAlarm => l10n.adviceFireAlarm,
      SoundKind.siren => l10n.adviceSiren,
      SoundKind.horn => l10n.adviceHorn,
      SoundKind.glassBreak => l10n.adviceGlassBreak,
      SoundKind.lineSignal => l10n.adviceLineSignal,
      _ => null,
    };

/// Sits above every screen (MaterialApp.builder) so an alert is never hidden.
class AlertOverlay extends StatefulWidget {
  const AlertOverlay({super.key, required this.child, this.signals = const BasicAlertSignals()});
  final Widget child;

  /// System notifications for the alert, so it is felt outside the app too (watch, locked phone, other tab).
  final AlertSignals signals;

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
      final label = alertLabel(l10n, alert);
      final exit = SettingsScope.of(context).emergencyExit.trim();
      final body = alert.level == AlertLevel.critical && exit.isNotEmpty ? l10n.alertExit(exit) : l10n.alertOpenApp;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.signals.notify(alert, label, body);
        // Screen readers announce the alert even if focus is elsewhere.
        SemanticsService.sendAnnouncement(View.of(context), label, Directionality.of(context));
      });
    } else if (alert == null && _announced != null) {
      _announced = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.signals.clear());
    }

    return Stack(
      children: [
        // While an alert covers the screen, the screen below is hidden from screen readers too.
        ExcludeSemantics(excluding: alert != null && alert.level != AlertLevel.info, child: widget.child),
        if (alert != null)
          switch (alert.level) {
            AlertLevel.info => _BannerAlert(alert: alert, onDismiss: controller.dismiss),
            _ => _FullScreenAlert(alert: alert, onDismiss: controller.dismiss),
          },
      ],
    );
  }
}

/// Critical (red, stays until acknowledged) and warning (amber, closes after 8 s) alerts:
/// the whole screen, with the level spelled out, the sound, what to do and one button.
class _FullScreenAlert extends StatelessWidget {
  const _FullScreenAlert({required this.alert, required this.onDismiss});
  final SoundAlert alert;
  final VoidCallback onDismiss;

  static const _red = Color(0xFFB00000);
  static const _amber = Color(0xFFFFC233);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final critical = alert.level == AlertLevel.critical;
    final background = critical ? _red : _amber;
    final foreground = critical ? Colors.white : Colors.black;
    final exit = SettingsScope.of(context).emergencyExit.trim();
    final advice = alertAdvice(l10n, alert);
    final organizations = ServicesScope.of(context).organizations;

    return Positioned.fill(
      child: Material(
        color: background,
        child: SafeArea(
          child: LayoutBuilder(
            // Scrolls instead of cutting text when the user's text size is very large; otherwise the
            // message sits in the middle and the button at the bottom, within thumb reach.
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: (constraints.maxHeight - 40).clamp(0, double.infinity)),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      Center(child: _LevelTag(critical: critical, color: foreground)),
                      const SizedBox(height: 28),
                      Center(
                        child: Container(
                          width: 128,
                          height: 128,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: foreground.withValues(alpha: 0.12)),
                          child: Icon(soundIcon(alert.kind), size: 68, color: foreground),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Semantics(
                        header: true,
                        liveRegion: true,
                        child: Text(
                          alertLabel(l10n, alert),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: foreground,
                            fontSize: 32,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      if (advice != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          advice,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: foreground,
                            fontSize: 19,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (critical && exit.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          l10n.alertExit(exit),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(color: foreground, fontWeight: FontWeight.w700),
                        ),
                      ],
                      const Spacer(),
                      const SizedBox(height: 32),
                      if (critical && (organizations?.any ?? false)) ...[
                        _RollCall(alert: alert, color: foreground, onSafe: onDismiss),
                        const SizedBox(height: 12),
                      ],
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: foreground,
                          foregroundColor: background,
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          textStyle: theme.textTheme.titleMedium?.copyWith(fontSize: 18),
                        ),
                        onPressed: onDismiss,
                        child: Text(l10n.alertDismiss),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "I'm safe" / "I need help" for members of a company: the admins see who answered.
/// "I'm safe" also closes the alert; after "I need help" the screen (and the exit) stays up.
class _RollCall extends StatefulWidget {
  const _RollCall({required this.alert, required this.color, required this.onSafe});
  final SoundAlert alert;
  final Color color;
  final VoidCallback onSafe;

  @override
  State<_RollCall> createState() => _RollCallState();
}

class _RollCallState extends State<_RollCall> {
  bool _sending = false;
  bool _sent = false;

  Future<void> _answer(AlarmAnswerStatus status) async {
    final organizations = ServicesScope.of(context).organizations!;
    final failed = AppLocalizations.of(context).orgError;
    setState(() => _sending = true);
    try {
      await organizations.answerAlarm(widget.alert.kind, status);
      if (!mounted) return;
      if (status == AlarmAnswerStatus.safe) {
        widget.onSafe();
      } else {
        setState(() => _sent = true);
      }
    } on Object {
      if (mounted) SemanticsService.sendAnnouncement(View.of(context), failed, Directionality.of(context));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = theme.textTheme.titleMedium?.copyWith(color: widget.color, fontWeight: FontWeight.w700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_sent)
          Semantics(liveRegion: true, child: Text(l10n.alertAnswerSent, textAlign: TextAlign.center, style: style))
        else ...[
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.color,
              side: BorderSide(color: widget.color, width: 1.5),
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: style,
            ),
            onPressed: _sending ? null : () => _answer(AlarmAnswerStatus.safe),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(l10n.alertSafe),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.color,
              side: BorderSide(color: widget.color, width: 1.5),
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              textStyle: style,
            ),
            onPressed: _sending ? null : () => _answer(AlarmAnswerStatus.needHelp),
            icon: const Icon(Icons.sos),
            label: Text(l10n.alertNeedHelp),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          l10n.orgRollCallNote,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: widget.color),
        ),
      ],
    );
  }
}

/// The level in words with its own icon, so it never depends on colour alone.
class _LevelTag extends StatelessWidget {
  const _LevelTag({required this.critical, required this.color});
  final bool critical;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(color: color.withValues(alpha: 0.14), shape: const StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(levelIcon(critical ? AlertLevel.critical : AlertLevel.warning), color: color, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                critical ? l10n.alertLevelCritical : l10n.alertLevelWarning,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerAlert extends StatefulWidget {
  const _BannerAlert({required this.alert, required this.onDismiss});
  final SoundAlert alert;
  final VoidCallback onDismiss;

  @override
  State<_BannerAlert> createState() => _BannerAlertState();
}

/// The small alert drops in from the top like a phone notification (ease-out, 260 ms; only a fade with
/// reduced motion) and is swiped away upward or closed with the button.
class _BannerAlertState extends State<_BannerAlert> with SingleTickerProviderStateMixin {
  late final _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 260))..forward();
  late final _curve = CurvedAnimation(parent: _enter, curve: const Cubic(0.23, 1, 0.32, 1));

  @override
  void didUpdateWidget(_BannerAlert old) {
    super.didUpdateWidget(old);
    if (!identical(old.alert, widget.alert)) _enter.forward(from: 0);
  }

  @override
  void dispose() {
    _curve.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = EchoPalette.of(context);
    final rise = !MediaQuery.disableAnimationsOf(context);
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: FadeTransition(
                opacity: _curve,
                child: AnimatedBuilder(
                  animation: _curve,
                  builder: (context, child) => FractionalTranslation(
                    translation: Offset(0, rise ? -(1 - _curve.value) : 0),
                    child: child,
                  ),
                  child: Dismissible(
                    key: ObjectKey(widget.alert),
                    direction: DismissDirection.up,
                    onDismissed: (_) => widget.onDismiss(),
                    child: Semantics(
                      liveRegion: true,
                      child: Material(
                        type: MaterialType.transparency,
                        child: GlassSurface(
                          radius: 24,
                          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                          child: Row(
                            children: [
                              RowIcon(soundIcon(widget.alert.kind)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  alertLabel(l10n, widget.alert),
                                  style: theme.textTheme.titleMedium?.copyWith(color: palette.text),
                                ),
                              ),
                              // No tooltip: it needs an Overlay, and this banner sits above the Navigator's.
                              IconButton(
                                onPressed: widget.onDismiss,
                                icon: Icon(Icons.close_rounded, color: palette.muted, semanticLabel: l10n.close),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
