import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../../theme/echo_style.dart';
import '../account/sign_in_screen.dart';
import '../emergency/alarm_api.dart';
import '../emergency/alarm_scope.dart';
import '../emergency/emergency_screen.dart';
import '../participant/join_screen.dart';
import '../settings/settings_screen.dart';
import '../sounds/sounds_screen.dart';
import 'home_screen.dart';

/// The phone's five main screens, in the bar's order.
enum EchoTab { home, meeting, sounds, alarm, settings }

/// The phone app's frame: the main screens with a floating bar at the bottom
/// (docs/superpowers/specs/2026-10-23-redesign-design.md). Screens opened from them are pushed over the
/// whole frame, so the bar only shows on the five main screens.
class PhoneShell extends StatefulWidget {
  const PhoneShell({super.key, this.initial = EchoTab.home});

  final EchoTab initial;

  static const barKey = Key('echo-nav');

  @override
  State<PhoneShell> createState() => _PhoneShellState();
}

class _PhoneShellState extends State<PhoneShell> {
  late EchoTab _tab = widget.initial;

  /// Tabs are built the first time they are shown, then kept (their state survives switching).
  late final _visited = <EchoTab>{widget.initial};

  void _select(EchoTab tab) => setState(() {
        _tab = tab;
        _visited.add(tab);
      });

  Widget _screen(EchoTab tab) => switch (tab) {
        EchoTab.home => const HomeScreen(presenterFirst: false),
        EchoTab.meeting => const JoinScreen(replaceOnJoin: false),
        EchoTab.sounds => const SoundsScreen(),
        EchoTab.alarm => const _AlarmTab(),
        EchoTab.settings => const SettingsScreen(),
      };

  @override
  Widget build(BuildContext context) {
    return ShellScope(
      tab: _tab,
      select: _select,
      child: Scaffold(
        // The screens end above the floating bar, so the last thing on every screen stays reachable,
        // whatever padding the screen itself uses.
        body: IndexedStack(
          index: _tab.index,
          children: [for (final tab in EchoTab.values) _visited.contains(tab) ? _screen(tab) : const SizedBox.shrink()],
        ),
        bottomNavigationBar: _FloatingBar(current: _tab, onSelect: _select),
      ),
    );
  }
}

/// Lets the main screens switch the bar (a card on Acasă opens the Meeting tab instead of a copy).
class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required this.tab, required this.select, required super.child});

  final EchoTab tab;
  final void Function(EchoTab tab) select;

  static ShellScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) => tab != oldWidget.tab;
}

class _FloatingBar extends StatelessWidget {
  const _FloatingBar({required this.current, required this.onSelect});

  final EchoTab current;
  final void Function(EchoTab tab) onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = EchoPalette.of(context);
    final highContrast = SettingsScope.of(context).highContrast;
    final items = [
      (EchoTab.home, Icons.home_outlined, Icons.home, l10n.navHome),
      (EchoTab.meeting, Icons.closed_caption_outlined, Icons.closed_caption, l10n.navMeeting),
      (EchoTab.sounds, Icons.hearing_outlined, Icons.hearing, l10n.navSounds),
      (EchoTab.alarm, Icons.emergency_share_outlined, Icons.emergency_share, l10n.navAlarm),
      (EchoTab.settings, Icons.settings_outlined, Icons.settings, l10n.navSettings),
    ];
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Semantics(
        container: true,
        label: l10n.navLabel,
        child: DecoratedBox(
          key: PhoneShell.barKey,
          decoration: BoxDecoration(
            color: palette.raised,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: highContrast ? palette.border : palette.border, width: highContrast ? 2 : 1),
            boxShadow: highContrast
                ? null
                : [BoxShadow(color: palette.text.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                for (final (tab, icon, selectedIcon, label) in items)
                  Expanded(
                    child: _BarItem(
                      icon: tab == current ? selectedIcon : icon,
                      label: label,
                      selected: tab == current,
                      onTap: () => onSelect(tab),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = EchoPalette.of(context);
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashFactory: NoSplash.splashFactory,
        child: AnimatedContainer(
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            // Selection shows by more than colour: filled icon, bold label and the pill behind them.
            color: selected ? palette.accentTint : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
            border: selected && SettingsScope.of(context).highContrast ? Border.all(color: palette.border, width: 2) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: selected ? palette.accent : palette.muted),
              const SizedBox(height: 2),
              // Big text sizes shrink the label to fit instead of cutting it.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected ? palette.text : palette.muted,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alarmă in the bar: the emergency screen for a signed-in colleague, otherwise why it needs an account.
class _AlarmTab extends StatelessWidget {
  const _AlarmTab();

  @override
  Widget build(BuildContext context) {
    final services = ServicesScope.of(context);
    final account = services.account;
    if (account == null) return const _AlarmUnavailable(signIn: false);
    return ListenableBuilder(
      listenable: account,
      builder: (context, _) {
        if (!account.isSignedIn) return const _AlarmUnavailable(signIn: true);
        final settings = SettingsScope.of(context);
        return EmergencyScreen(
          api: AlarmApi(defaultServer(settings), client: services.httpClient, token: () => services.account?.accessToken),
          positions: services.positions,
          onRaised: AlarmScope.maybeOf(context)?.markOwn ?? (_) {},
          memory: AlarmScope.maybeOf(context)?.sentAlarm,
        );
      },
    );
  }
}

class _AlarmUnavailable extends StatelessWidget {
  const _AlarmUnavailable({required this.signIn});

  /// Accounts are on, so signing in is the way to the alarm.
  final bool signIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = EchoPalette.of(context);
    final account = ServicesScope.of(context).account;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.emergencyTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Icon(Icons.emergency_share_outlined, size: 48, color: palette.brand),
            ),
            const SizedBox(height: 16),
            Text(signIn ? l10n.alarmNeedsAccount : l10n.alarmAccountsOff, style: theme.textTheme.bodyLarge),
            if (signIn && account != null) ...[
              const SizedBox(height: 24),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SignInScreen(account: account))),
                  child: Text(l10n.signIn),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
