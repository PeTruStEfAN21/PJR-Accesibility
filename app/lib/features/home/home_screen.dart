import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/org/org_store.dart';
import '../../core/services.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../../widgets/echo_logo.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/pressable.dart';
import '../../theme/echo_style.dart';
import '../account/account_screen.dart';
import '../announcements/announcements_section.dart';
import '../account/sign_in_screen.dart';
import '../coach/coach_screen.dart';
import '../conversation/conversation_screen.dart';
import '../emergency/alarm_api.dart';
import '../emergency/alarm_scope.dart';
import '../emergency/emergency_screen.dart';
import '../history/history_screen.dart';
import '../participant/join_screen.dart';
import '../presenter/presenter_screen.dart';
import '../settings/settings_screen.dart';
import '../sounds/sounds_screen.dart';
import 'phone_shell.dart';

/// The clarity coach's entry on the laptop home; off until the team decides to show it again.
const showOnlineCoach = false;

/// One obvious main action per device: joining on the phone, presenting on the laptop.
///
/// The browser build holds both apps: a phone-sized screen (a phone's browser, or a narrow window) gets
/// the phone app, a wider one the presenter's home. Each links to the other.
///
/// Visual direction: taste-skill "editorial-greeting" (seed 1600705491): the greeting as the title,
/// tonal panels instead of shadows, one deep-teal accent, pill controls.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.presenterFirst, this.web = kIsWeb});

  /// True for the presenter's home, false for the phone app; null decides by device and screen width.
  final bool? presenterFirst;

  /// Running in a browser, where both apps live in one build.
  final bool web;

  /// Up to this width a browser shows the phone app.
  static const phoneMaxWidth = 600.0;

  static const _tipId = 'home';

  /// From this width the tip sits beside the main action instead of above it.
  static const _wideFrom = 840.0;

  /// The centred column on wide screens: 12 columns of 77px with 16px gutters.
  static const _columnWidth = 1100.0;

  static double _sideMargin(double width) => ((width - _columnWidth) / 2).clamp(32.0, double.infinity);

  @override
  Widget build(BuildContext context) {
    final services = ServicesScope.of(context);
    final account = services.account;
    // Accounts are optional: without Supabase configured the home screen is unchanged.
    if (account == null) return _build(context);
    // The companies arrive after signing in and pick the employee's laptop page.
    return ListenableBuilder(
      listenable: Listenable.merge([account, ?services.organizations]),
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final presenterFirst = this.presenterFirst ?? (web && MediaQuery.sizeOf(context).width > phoneMaxWidth);
    final l10n = AppLocalizations.of(context);
    final settings = SettingsScope.of(context);
    final palette = EchoPalette.of(context);
    final services = ServicesScope.of(context);
    final account = services.account;
    final meetings = services.signedInMeetings;
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    void markTipSeen() {
      if (!settings.seenTips.contains(_tipId)) settings.update((s) => s.seenTips.add(_tipId));
    }

    // Inside the phone's frame, cards for the bar's own screens switch the bar instead of opening a copy.
    final shell = ShellScope.maybeOf(context);
    void openFromCard(Widget screen, {EchoTab? tab}) {
      markTipSeen();
      if (shell != null && tab != null) {
        shell.select(tab);
      } else {
        open(screen);
      }
    }

    Widget joinAction({bool fill = false}) => _MainAction(icon: Icons.closed_caption_outlined, title: l10n.homeJoin, hint: l10n.homeJoinHint, onTap: () => openFromCard(const JoinScreen(), tab: EchoTab.meeting), fill: fill);

    Widget presentAction({bool fill = false}) => _MainAction(icon: Icons.co_present_outlined, title: l10n.homePresent, hint: l10n.homePresentHint, onTap: () => openFromCard(const PresenterScreen()), fill: fill);

    Widget mainAction({bool fill = false}) => presenterFirst ? presentAction(fill: fill) : joinAction(fill: fill);

    // An employee's laptop page follows how they take part (docs/superpowers/specs/2026-10-23-taburi-dupa-tip-design.md):
    // announcements, then joining large, then presenting next to Vibrații (reads) or Urgență (hears).
    // The admin and someone in no company keep the presenter's page for now.
    final experience = presenterFirst ? services.organizations?.employeeExperience : null;
    // The admin's laptop page: no Vibrații card and no Vorbesc cu cineva.
    final admin = presenterFirst && (services.organizations?.isAdminAnywhere ?? false);

    // Sound recognition runs on the phone (TFLite) and in the browser (TensorFlow.js), so both show it.
    Widget soundsAction({bool fill = false}) => ListenableBuilder(
          listenable: services.soundListening,
          builder: (context, _) {
            final listening = services.soundListening;
            final on = services.sounds.isAvailable && listening.wanted && !listening.paused;
            return _MainAction(
              icon: on ? Icons.vibration_outlined : Icons.notifications_off_outlined,
              title: l10n.homeSounds,
              hint: !services.sounds.isAvailable
                  ? l10n.homeSoundsUnavailable
                  : listening.paused
                      ? l10n.homeSoundsPaused
                      : listening.wanted
                          ? l10n.homeSoundsOn
                          : l10n.homeSoundsOff,
              // The card only opens the Sounds screen, which holds the switch and says why when unavailable.
              onTap: () => openFromCard(const SoundsScreen(), tab: EchoTab.sounds),
              fill: fill,
            );
          },
        );

    Widget emergencyScreen() => EmergencyScreen(
          api: AlarmApi(defaultServer(settings), client: services.httpClient, token: () => services.account?.accessToken),
          positions: services.positions,
          onRaised: AlarmScope.maybeOf(context)?.markOwn ?? (_) {},
          memory: AlarmScope.maybeOf(context)?.sentAlarm,
        );

    Widget emergencyAction({bool fill = false}) => _MainAction(
          icon: Icons.emergency_share_outlined,
          title: l10n.emergencyTitle,
          hint: l10n.emergencyHomeHint,
          onTap: () => openFromCard(emergencyScreen(), tab: EchoTab.alarm),
          fill: fill,
        );

    Widget elsewhere() => _Elsewhere(
          title: l10n.homeElsewhere,
          rows: [
            // Not on an employee's or the admin's page (the team chose to leave it out there).
            if (experience == null && !admin)
              _ToolRow(icon: Icons.forum_outlined, title: l10n.homeConversation, hint: l10n.homeConversationHint, onTap: () => open(const ConversationScreen())),
            if (meetings != null)
              _ToolRow(icon: Icons.history_rounded, title: l10n.homeHistory, hint: l10n.homeHistoryHint, onTap: () => open(HistoryScreen(meetings: meetings))),
            // Raising an alarm needs an account: the name is kept with it.
            // In the phone's frame the alarm has its own entry in the bar; an employee's laptop page has it
            // as a card (hears) or not at all (reads what is said: colleagues raise it for them).
            if (account?.isSignedIn == true && shell == null && experience == null)
              _ToolRow(
                icon: Icons.emergency_share_outlined,
                title: l10n.emergencyTitle,
                hint: l10n.emergencyHomeHint,
                onTap: () => openFromCard(emergencyScreen(), tab: EchoTab.alarm),
              ),
          ],
        );

    final showTip = settings.shouldShowTip(_tipId);
    Widget tip({bool inRow = false}) => _Tip(
          text: presenterFirst ? l10n.homeTipPresent : l10n.homeTipJoin,
          onGotIt: markTipSeen,
          onSkip: () => settings.update((s) => s.tipsEnabled = false),
          inRow: inRow,
        );

    // The bar sits close to the window's edges: the logo top left, settings top right.
    final wideBar = MediaQuery.sizeOf(context).width >= _wideFrom;
    final barSide = wideBar ? 24.0 : 12.0;

    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: palette.ground)),
        // A faint cyan glow behind the greeting, echoing the logo; none in high contrast.
        if (!SettingsScope.of(context).highContrast)
          Positioned(
            top: -150,
            left: -130,
            child: IgnorePointer(
              child: Container(
                width: 460,
                height: 460,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [EchoLogo.brandColor.withValues(alpha: 0.16), EchoLogo.brandColor.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
        Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: palette.text,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        // The wordmark is the name; high contrast draws it in ink.
        toolbarHeight: wideBar ? 88 : 72,
        titleSpacing: barSide,
        title: EchoLogo(
          height: wideBar ? 58 : 46,
          semanticLabel: l10n.appTitle,
          color: SettingsScope.of(context).highContrast ? palette.text : EchoLogo.brandColor,
        ),
        actions: [
          if (account != null)
            IconButton(
              tooltip: account.isSignedIn ? l10n.account : l10n.signIn,
              icon: Icon(account.isSignedIn ? Icons.account_circle_outlined : Icons.login_rounded, color: palette.brand),
              onPressed: () => open(
                meetings != null
                    ? AccountScreen(account: account, meetings: meetings)
                    : SignInScreen(account: account),
              ),
            ),
          // In the phone's frame, Setări is in the bar.
          if (shell == null)
            IconButton(
              tooltip: l10n.settings,
              icon: Icon(Icons.settings_outlined, color: palette.brand),
              onPressed: () => open(const SettingsScreen()),
            ),
          // The icon's own padding is 8, so the glyph ends on the column's right edge.
          SizedBox(width: barSide - 8),
        ],
      ),
      // The bottom inset goes inside the list, so content scrolls under the phone's glass bar.
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _wideFrom;
            final side = wide ? _sideMargin(constraints.maxWidth) : 20.0;
            return ListView(
              padding: EdgeInsets.fromLTRB(side, wide ? 56 : 12, side, 32 + MediaQuery.paddingOf(context).bottom),
              children: [
                // No greeting: the phone's Dashboard opens on the announcements, the laptop on its cards.
                if (shell != null) const AnnouncementsSection(first: true, folded: true),
                if (experience != null) ...[
                  const AnnouncementsSection(first: true),
                  joinAction(),
                  const SizedBox(height: 16),
                  if (wide)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: presentAction(fill: true)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: experience == MemberExperience.visual
                                ? soundsAction(fill: true)
                                : emergencyAction(fill: true),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    presentAction(),
                    const SizedBox(height: 16),
                    experience == MemberExperience.visual ? soundsAction() : emergencyAction(),
                  ],
                  if (showTip) ...[const SizedBox(height: 16), tip()],
                ] else if (wide && showTip)
                  // 7 + 5 of the 12 columns; both panels end on one bottom edge.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 7, child: mainAction(fill: true)),
                        const SizedBox(width: 16),
                        Expanded(flex: 5, child: tip(inRow: true)),
                      ],
                    ),
                  )
                else ...[
                  if (showTip) ...[tip(), const SizedBox(height: 16)],
                  // In the phone's frame, joining and sounds are in the bar: Acasă does not repeat them.
                  if (shell == null) mainAction(),
                ],
                // Right under the main action, like a landing page; nothing for someone in no company.
                if (shell == null && experience == null) const AnnouncementsSection(),
                // The laptop also has everything the phone app has: joining and sounds side by side.
                if (presenterFirst && experience == null && admin) ...[
                  const SizedBox(height: 16),
                  joinAction(),
                ] else if (presenterFirst && experience == null) ...[
                  const SizedBox(height: 16),
                  if (wide)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: joinAction(fill: true)),
                          const SizedBox(width: 16),
                          Expanded(child: soundsAction(fill: true)),
                        ],
                      ),
                    )
                  else ...[
                    joinAction(),
                    const SizedBox(height: 16),
                    soundsAction(),
                  ],
                ] else if (shell == null && !presenterFirst) ...[
                  const SizedBox(height: 16),
                  soundsAction(),
                ],
                // Online meetings: the hearing colleague's clarity coach runs in Chrome on their computer.
                // Hidden for now (the team decides whether it stays); the coach itself is unchanged.
                if (presenterFirst && showOnlineCoach) ...[
                  const SizedBox(height: 16),
                  _Elsewhere(
                    title: l10n.homeOnline,
                    rows: [
                      _ToolRow(icon: Icons.record_voice_over_outlined, title: l10n.homeCoach, hint: l10n.homeCoachHint, onTap: () => open(const CoachScreen())),
                    ],
                  ),
                ],
                if (shell == null) ...[const SizedBox(height: 16), elsewhere()],
                // The laptop shows joining as a card; the phone without the frame links to presenting
                // (in the frame, presenting is in the Meeting tab).
                if (!presenterFirst && shell == null) ...[
                  const SizedBox(height: 24),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      // No side padding, so the link's text starts on the panels' left edge.
                      style: EchoButtons.link(palette, flush: true),
                      onPressed: () => open(const PresenterScreen()),
                      child: Text(l10n.homeOtherPresent),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    ),
      ],
    );
  }
}

/// The single prominent action: a large accent-tinted panel with a plain-language explanation.
class _MainAction extends StatelessWidget {
  const _MainAction({required this.icon, required this.title, required this.hint, required this.onTap, this.fill = false});

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  /// True when the panel is stretched to its row-mate's height: the words then sit at its foot.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = EchoPalette.of(context);
    final highContrast = SettingsScope.of(context).highContrast;
    final shape = BorderRadius.circular(26);
    return Pressable(
      child: MergeSemantics(
      child: Semantics(
        button: true,
        // A soft cyan gradient with a light top edge and a gentle shadow; flat in high contrast.
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: shape,
            boxShadow: highContrast
                ? null
                : [BoxShadow(color: EchoPalette.shadow.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: shape),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: shape,
              color: highContrast ? palette.accentTint : null,
              gradient: highContrast
                  ? null
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [EchoPalette.cardTop, EchoPalette.cardBottom],
                    ),
              border: Border.all(color: highContrast ? palette.border : Colors.white, width: highContrast ? 2 : 1.5),
            ),
            child: InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            highlightColor: palette.text.withValues(alpha: 0.05),
            hoverColor: palette.text.withValues(alpha: 0.03),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Chip(size: 52, child: Icon(icon, size: 28, color: palette.accent)),
                      const Spacer(),
                      _Chip(size: 40, round: true, child: Icon(Icons.arrow_forward, size: 20, color: palette.text)),
                    ],
                  ),
                  if (fill) const Spacer() else const SizedBox(height: 32),
                  Text(title, style: theme.textTheme.headlineSmall?.copyWith(color: palette.text, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text(hint, style: theme.textTheme.bodyLarge?.copyWith(color: palette.text)),
                ],
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

/// A frosted rounded chip holding an icon: the small premium accent on Echo's cards.
class _Chip extends StatelessWidget {
  const _Chip({required this.size, required this.child, this.round = false});

  final double size;
  final Widget child;
  final bool round;

  @override
  Widget build(BuildContext context) {
    final palette = EchoPalette.of(context);
    final highContrast = SettingsScope.of(context).highContrast;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: highContrast ? palette.raised : Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(round ? size / 2 : size * 0.34),
        border: Border.all(color: highContrast ? palette.border : Colors.white, width: highContrast ? 2 : 1),
        boxShadow: highContrast
            ? null
            : [BoxShadow(color: EchoPalette.shadow.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Center(child: child),
    );
  }
}

/// Secondary tools, grouped in one tonal panel so they never compete with the main action.
class _Elsewhere extends StatelessWidget {
  const _Elsewhere({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = EchoPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: palette.text, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            row,
          ],
        ],
      ),
    );
  }
}

/// A row card inside the "elsewhere" panel: one step lighter, with a border one step darker.
class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.icon, required this.title, required this.hint, required this.onTap});

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = EchoPalette.of(context);
    return Pressable(
      child: MergeSemantics(
      child: Semantics(
        button: true,
        child: Material(
          color: palette.raised,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: palette.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            highlightColor: palette.text.withValues(alpha: 0.05),
            hoverColor: palette.text.withValues(alpha: 0.03),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Row(
                children: [
                  RowIcon(icon),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium?.copyWith(color: palette.text, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(hint, style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: palette.muted),
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

/// First-run hint shown in context instead of an up-front tour.
class _Tip extends StatelessWidget {
  const _Tip({required this.text, required this.onGotIt, required this.onSkip, this.inRow = false});

  final String text;
  final VoidCallback onGotIt;
  final VoidCallback onSkip;

  /// True beside the main action, inside an IntrinsicHeight, where OverflowBar cannot be measured.
  final bool inRow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = EchoPalette.of(context);
    final skip = TextButton(
      style: EchoButtons.link(palette),
      onPressed: onSkip,
      child: Semantics(label: l10n.tipSkipLabel, excludeSemantics: true, child: Text(l10n.tipSkip)),
    );
    final gotIt = Pressable(
      child: FilledButton(
        style: EchoButtons.primary(palette),
        onPressed: onGotIt,
        child: Text(l10n.tipGotIt),
      ),
    );
    final highContrast = SettingsScope.of(context).highContrast;
    // Large text no longer fits the two buttons side by side in the narrow column.
    final stacked = inRow && MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: highContrast ? Border.all(color: palette.border, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 20, color: palette.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l10n.tipTitle, style: theme.textTheme.titleSmall?.copyWith(color: palette.text, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: theme.textTheme.bodyLarge?.copyWith(color: palette.text)),
          const SizedBox(height: 12),
          if (stacked)
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [gotIt, skip])
          else if (inRow)
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [skip, const SizedBox(width: 8), gotIt])
          else
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              overflowAlignment: OverflowBarAlignment.end,
              children: [skip, gotIt],
            ),
        ],
      ),
    );
  }
}
