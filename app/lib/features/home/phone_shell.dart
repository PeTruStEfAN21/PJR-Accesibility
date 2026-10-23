import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../../theme/echo_style.dart';
import '../../widgets/glass.dart';
import '../../widgets/large_title.dart';
import '../account/sign_in_screen.dart';
import '../emergency/alarm_api.dart';
import '../emergency/alarm_scope.dart';
import '../emergency/emergency_screen.dart';
import '../settings/settings_screen.dart';
import '../sounds/sounds_screen.dart';
import 'home_screen.dart';
import 'meeting_tab.dart';

/// The phone's five main screens, in the bar's order.
enum EchoTab { home, meeting, sounds, alarm, settings }

/// The phone app's frame: the main screens with a floating bar at the bottom
/// (docs/specs/2026-10-23-redesign-design.md). Screens opened from them are pushed over the
/// whole frame, so the bar only shows on the five main screens.
class PhoneShell extends StatefulWidget {
  const PhoneShell({super.key, this.initial = EchoTab.home});

  final EchoTab initial;

  static const barKey = Key('echo-nav');

  @override
  State<PhoneShell> createState() => _PhoneShellState();
}

class _PhoneShellState extends State<PhoneShell> with SingleTickerProviderStateMixin {
  late EchoTab _tab = widget.initial;

  /// The tab fading out under the new one, until the fade ends.
  EchoTab? _leaving;

  /// Tabs are built the first time they are shown, then kept (their state survives switching).
  late final _visited = <EchoTab>{widget.initial};

  /// The new tab fades in over the old one and rises 8 px: quick and subtle, since switching tabs
  /// happens often. Strong ease-out, 200 ms; with reduced motion only the fade remains.
  late final _switch = AnimationController(vsync: this, duration: const Duration(milliseconds: 200), value: 1)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && _leaving != null) setState(() => _leaving = null);
    });
  late final _curve = CurvedAnimation(parent: _switch, curve: const Cubic(0.23, 1, 0.32, 1));

  void _select(EchoTab tab) {
    if (tab == _tab) return;
    setState(() {
      _leaving = _tab;
      _tab = tab;
      _visited.add(tab);
    });
    _switch.forward(from: 0);
  }

  @override
  void dispose() {
    _curve.dispose();
    _switch.dispose();
    super.dispose();
  }

  Widget _screen(EchoTab tab) => switch (tab) {
    EchoTab.home => const HomeScreen(presenterFirst: false),
    EchoTab.meeting => const MeetingTab(),
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
        // Content scrolls under the glass bar; each main screen puts the bar's height inside its list
        // (MediaQuery bottom padding), so its last item still ends above the bar.
        extendBody: true,
        body: Stack(
          fit: StackFit.expand,
          // Keyed and reordered so the new tab paints on top of the one leaving; each keeps its state.
          children: [
            for (final tab in [
              ...EchoTab.values.where((t) => _visited.contains(t) && t != _tab && t != _leaving),
              ?_leaving,
              _tab,
            ])
              _TabLayer(
                key: ValueKey(tab),
                shown: tab == _tab || tab == _leaving,
                active: tab == _tab,
                animation: tab == _tab ? _curve : kAlwaysCompleteAnimation,
                rise: !MediaQuery.disableAnimationsOf(context),
                child: _screen(tab),
              ),
          ],
        ),
        bottomNavigationBar: _FloatingBar(current: _tab, onSelect: _select),
      ),
    );
  }
}

/// One main screen in the shell. Hidden tabs stay built but offstage, with their animations paused, so
/// switching back is instant; each sits on its own layer so the fade repaints nothing inside it.
class _TabLayer extends StatelessWidget {
  const _TabLayer({
    super.key,
    required this.shown,
    required this.active,
    required this.animation,
    required this.rise,
    required this.child,
  });

  final bool shown;

  /// The tab the bar has selected: the only one that takes touches and is read by VoiceOver.
  final bool active;
  final Animation<double> animation;

  /// False with reduced motion: the tab only fades.
  final bool rise;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: !shown,
      child: TickerMode(
        enabled: shown,
        child: IgnorePointer(
          ignoring: !active,
          child: ExcludeSemantics(
            excluding: !active,
            child: FadeTransition(
              opacity: animation,
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, rise ? 8 * (1 - animation.value) : 0),
                  child: child,
                ),
                child: RepaintBoundary(child: child),
              ),
            ),
          ),
        ),
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
    final items = [
      (EchoTab.home, Icons.space_dashboard_outlined, Icons.space_dashboard, l10n.navHome),
      (EchoTab.meeting, Icons.closed_caption_outlined, Icons.closed_caption, l10n.navMeeting),
      (EchoTab.sounds, Icons.vibration_outlined, Icons.vibration, l10n.navSounds),
      (EchoTab.alarm, Icons.emergency_share_outlined, Icons.emergency_share, l10n.navAlarm),
      (EchoTab.settings, Icons.settings_outlined, Icons.settings, l10n.navSettings),
    ];
    // Five labels share a phone's width: like iOS tab bars, they grow with the text size only up to
    // 130%, so all five stay whole and the same size. The screens above keep growing to 200%.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Semantics(
          container: true,
          label: l10n.navLabel,
          child: GlassSurface(
            key: PhoneShell.barKey,
            radius: 32,
            padding: const EdgeInsets.all(6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // One size for all five labels: the largest at which the longest one fits its slot.
                final style = _labelStyle(context, selected: true);
                final scaler = MediaQuery.textScalerOf(context);
                final slot = constraints.maxWidth / items.length - 4;
                var widest = 0.0;
                for (final (_, _, _, label) in items) {
                  final painter = TextPainter(
                    text: TextSpan(text: label, style: style),
                    textScaler: scaler,
                    textDirection: Directionality.of(context),
                    maxLines: 1,
                  )..layout();
                  if (painter.width > widest) widest = painter.width;
                  painter.dispose();
                }
                final fit = widest > slot ? slot / widest : 1.0;
                final labelScaler = TextScaler.linear(scaler.scale(1) * fit);
                return Stack(
                  children: [
                    // The selection pill glides to the chosen entry (instantly with reduced motion).
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, box) => Stack(
                          children: [
                            GlassPill(
                              index: current.index,
                              count: items.length,
                              height: box.maxHeight,
                              width: box.maxWidth,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final (tab, icon, selectedIcon, label) in items)
                          Expanded(
                            child: _BarItem(
                              icon: tab == current ? selectedIcon : icon,
                              label: label,
                              labelScaler: labelScaler,
                              selected: tab == current,
                              onTap: () => onSelect(tab),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

TextStyle? _labelStyle(BuildContext context, {required bool selected}) {
  final palette = EchoPalette.of(context);
  return Theme.of(context).textTheme.labelMedium?.copyWith(
    color: selected ? palette.text : palette.muted,
    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
  );
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.icon,
    required this.label,
    required this.labelScaler,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;

  /// The same for the five labels (see [_FloatingBar]).
  final TextScaler labelScaler;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = EchoPalette.of(context);
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
          // Selection shows by more than colour: filled icon, bold label and the pill gliding behind them.
          decoration: const BoxDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: selected ? palette.accent : palette.muted),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                textScaler: labelScaler,
                style: _labelStyle(context, selected: selected),
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
          api: AlarmApi(
            defaultServer(settings),
            client: services.httpClient,
            token: () => services.account?.accessToken,
          ),
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
      appBar: backBarIfPushed(context, l10n.emergencyTitle),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.paddingOf(context).bottom),
          children: [
            LargeTitle(l10n.emergencyTitle),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: palette.accentTint, borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.emergency_share_outlined, size: 28, color: palette.accent),
              ),
            ),
            const SizedBox(height: 16),
            Text(signIn ? l10n.alarmNeedsAccount : l10n.alarmAccountsOff, style: theme.textTheme.bodyLarge),
            if (signIn && account != null) ...[
              const SizedBox(height: 24),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => SignInScreen(account: account))),
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
