import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../../theme/echo_style.dart';
import '../../widgets/pressable.dart';
import '../alerts/sound_alert.dart';
import 'alarm_api.dart';
import 'alarm_logic.dart';
import 'position_source.dart';

/// Raising an alarm by hand, for dangers the app cannot hear. Needs a signed-in user and a position.
///
/// Same visual direction as the home screen (taste-skill "editorial-greeting"): tonal panels,
/// row cards, one filled button per state (in the confirmation dialog), links for the rest.
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key, required this.api, required this.positions, required this.onRaised});

  final AlarmApi api;
  final PositionSource positions;

  /// Told the id of each alarm sent, so this phone does not alert itself.
  final void Function(String id) onRaised;

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  RaisedAlarm? _sent;
  AlarmKind? _sentKind;
  bool _cancelled = false;
  String? _error;

  String _problem(AppLocalizations l10n, AlarmError error) => switch (error.problem) {
        AlarmProblem.signedOut => l10n.emergencyErrorSignedOut,
        AlarmProblem.notConfigured => l10n.emergencyErrorNotConfigured,
        AlarmProblem.tooMany => l10n.emergencyErrorTooMany(((error.retryAfterSeconds ?? 3600) / 60).ceil()),
        AlarmProblem.offline => l10n.emergencyErrorOffline,
        AlarmProblem.failed => l10n.emergencyErrorFailed,
      };

  Future<void> _raise(AlarmKind kind) async {
    final l10n = AppLocalizations.of(context);
    // The sender must say where the danger is; receivers without a fix still get every alarm.
    final at = await widget.positions.current() ?? await widget.positions.lastKnown();
    if (!mounted) return;
    if (at == null) {
      setState(() => _error = l10n.emergencyErrorLocation);
      return;
    }
    try {
      final alarm = await widget.api.raise(kind, at);
      widget.onRaised(alarm.id);
      if (!mounted) return;
      setState(() {
        _sent = alarm;
        _sentKind = kind;
        _cancelled = false;
        _error = null;
      });
    } on AlarmError catch (error) {
      if (mounted) setState(() => _error = _problem(l10n, error));
    }
  }

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    try {
      await widget.api.cancel(_sent!.id);
      if (!mounted) return;
      setState(() {
        _sent = null;
        _sentKind = null;
        _cancelled = true;
        _error = null;
      });
    } on AlarmError catch (error) {
      if (mounted) setState(() => _error = _problem(l10n, error));
    }
  }

  void _confirmRaise(AlarmKind kind) {
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);
    showDialog<void>(
      context: context,
      builder: (_) => _ConfirmDialog(
        question: l10n.emergencyConfirm(alarmName(l10n, kind)),
        confirm: l10n.emergencySend,
        action: () => _raise(kind),
      ),
    );
  }

  void _confirmCancel() {
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);
    showDialog<void>(
      context: context,
      builder: (_) => _ConfirmDialog(
        question: l10n.emergencyCancelConfirm,
        confirm: l10n.emergencyCancelAlarm,
        action: _cancel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = EchoPalette.of(context);
    final theme = Theme.of(context);
    final sent = _sent;

    return Scaffold(
      backgroundColor: palette.ground,
      appBar: AppBar(
        backgroundColor: palette.ground,
        foregroundColor: palette.text,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(l10n.emergencyTitle, style: theme.textTheme.titleLarge?.copyWith(color: palette.text, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(l10n.emergencyIntro, style: theme.textTheme.bodyLarge?.copyWith(color: palette.text)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(child: Icon(Icons.badge_outlined, size: 20, color: palette.muted)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l10n.emergencyAccountable, style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (sent != null)
                  _SentPanel(
                    kind: _sentKind!,
                    at: sent.at,
                    error: _error,
                    onCancel: _confirmCancel,
                  )
                else ...[
                  if (_cancelled) ...[
                    _Status(icon: Icons.check_circle_outline, text: l10n.emergencyCancelled),
                    const SizedBox(height: 16),
                  ],
                  _KindList(onPick: _confirmRaise),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _ErrorNote(text: _error!),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The four kinds in one tonal panel, as large row cards.
class _KindList extends StatelessWidget {
  const _KindList({required this.onPick});

  final void Function(AlarmKind kind) onPick;

  @override
  Widget build(BuildContext context) {
    final palette = EchoPalette.of(context);
    final highContrast = SettingsScope.of(context).highContrast;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: highContrast ? Border.all(color: palette.border, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, kind) in AlarmKind.values.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            _KindRow(kind: kind, onTap: () => onPick(kind)),
          ],
        ],
      ),
    );
  }
}

/// One kind: icon, name and the level in words, never only colour.
class _KindRow extends StatelessWidget {
  const _KindRow({required this.kind, required this.onTap});

  final AlarmKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = EchoPalette.of(context);
    final name = alarmName(l10n, kind);
    final critical = kind.level == AlertLevel.critical;
    final level = critical ? l10n.alarmLevelCritical : l10n.alarmLevelWarning;
    return Pressable(
      child: Semantics(
        button: true,
        label: '$name, $level',
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: palette.raised,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: palette.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            highlightColor: palette.text.withValues(alpha: 0.05),
            hoverColor: palette.text.withValues(alpha: 0.03),
            focusColor: palette.accent.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Row(
                children: [
                  Icon(kind.icon, size: 28, color: palette.text),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: theme.textTheme.titleMedium?.copyWith(color: palette.text, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(
                          level,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: palette.muted,
                            fontWeight: critical ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: palette.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// After sending: when it went out, and the way to take it back.
class _SentPanel extends StatelessWidget {
  const _SentPanel({required this.kind, required this.at, required this.error, required this.onCancel});

  final AlarmKind kind;
  final DateTime at;
  final String? error;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = EchoPalette.of(context);
    final highContrast = SettingsScope.of(context).highContrast;
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(at), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context));
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      decoration: BoxDecoration(
        color: palette.accentTint,
        borderRadius: BorderRadius.circular(22),
        border: highContrast ? Border.all(color: palette.border, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: Icon(kind.icon, size: 28, color: palette.text)),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alarmName(l10n, kind), style: theme.textTheme.titleMedium?.copyWith(color: palette.text, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(l10n.emergencySent(time), style: theme.textTheme.bodyLarge?.copyWith(color: palette.text)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            _ErrorNote(text: error!),
          ],
          const SizedBox(height: 8),
          TextButton(
            style: EchoButtons.link(palette, flush: true),
            onPressed: onCancel,
            child: Text(l10n.emergencyCancelAlarm),
          ),
        ],
      ),
    );
  }
}

/// A short confirmation line, read out when it appears.
class _Status extends StatelessWidget {
  const _Status({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = EchoPalette.of(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(icon, size: 20, color: palette.accent)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: palette.text))),
        ],
      ),
    );
  }
}

/// What went wrong and how to fix it, in the screen, read out when it appears.
class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = EchoPalette.of(context);
    final error = Theme.of(context).colorScheme.error;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.raised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: error),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(Icons.error_outline, size: 22, color: error)),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: palette.text))),
          ],
        ),
      ),
    );
  }
}

/// Asks once more before an alarm goes out or is taken back. The request runs from here, so the
/// filled button can say "Sending…" (at the same width) and cannot be pressed twice.
class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({required this.question, required this.confirm, required this.action});

  final String question;
  final String confirm;
  final Future<void> Function() action;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool _sending = false;

  Future<void> _go() async {
    if (_sending) return;
    setState(() => _sending = true);
    await widget.action();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = EchoPalette.of(context);
    final theme = Theme.of(context);
    // Both labels are laid out; only one shows, so the button never changes width.
    Widget label(String text, bool visible) =>
        Visibility(visible: visible, maintainSize: true, maintainAnimation: true, maintainState: true, child: Text(text));
    return PopScope(
      canPop: !_sending,
      child: AlertDialog(
        backgroundColor: palette.ground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        content: Text(widget.question, style: theme.textTheme.titleLarge?.copyWith(color: palette.text)),
        actions: [
          TextButton(
            style: EchoButtons.link(palette),
            onPressed: _sending ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.emergencyCancelDialog),
          ),
          Pressable(
            child: FilledButton(
              style: EchoButtons.primary(palette),
              onPressed: _go,
              child: Stack(
                alignment: Alignment.center,
                children: [label(widget.confirm, !_sending), label(l10n.emergencySending, _sending)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
