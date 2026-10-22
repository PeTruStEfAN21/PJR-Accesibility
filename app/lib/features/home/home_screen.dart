import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../../widgets/echo_logo.dart';
import '../../widgets/pressable.dart';
import '../../theme/echo_style.dart';
import '../account/account_screen.dart';
import '../account/sign_in_screen.dart';
import '../conversation/conversation_screen.dart';
import '../history/history_screen.dart';
import '../participant/join_screen.dart';
import '../presenter/presenter_screen.dart';
import '../settings/settings_screen.dart';
import '../sounds/sounds_screen.dart';

/// `--dart-define=ECHO_PHONE_PREVIEW=true` shows the phone layout in Chrome, for design reviews.
const _phonePreview = bool.fromEnvironment('ECHO_PHONE_PREVIEW');

/// One obvious main action per device: joining on the phone, presenting on the laptop (Chrome).
///
/// Visual direction: "editorial-greeting" (seed 1600705491): the greeting as the title,
/// tonal panels instead of shadows, one deep-teal accent, pill controls.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.presenterFirst = kIsWeb && !_phonePreview});

  /// True on the presenter's laptop. Sounds and face captions need the phone, so they are hidden there.
  final bool presenterFirst;

  static const _tipId = 'home';

  /// From this width the tip sits beside the main action instead of above it.
  static const _wideFrom = 840.0;

  /// The centred column on wide screens: 12 columns of 77px with 16px gutters.
  static const _columnWidth = 1100.0;

  @override
  Widget build(BuildContext context) {
    final account = ServicesScope.of(context).account;
    // Accounts are optional: without Supabase configured the home screen is unchanged.
    if (account == null) return _build(context);
    return ListenableBuilder(listenable: account, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = SettingsScope.of(context);
    final palette = EchoPalette.of(context);
    final theme = Theme.of(context);
    final services = ServicesScope.of(context);
    final account = services.account;
    final meetings = services.signedInMeetings;
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    void markTipSeen() {
      if (!settings.seenTips.contains(_tipId)) settings.update((s) => s.seenTips.add(_tipId));
    }

    void openMain() {
      markTipSeen();
      open(presenterFirst ? const PresenterScreen() : const JoinScreen());
    }

    Widget mainAction({bool fill = false}) => presenterFirst
        ? _MainAction(icon: Icons.co_present_outlined, title: l10n.homePresent, hint: l10n.homePresentHint, onTap: openMain, fill: fill)
        : _MainAction(icon: Icons.closed_caption_outlined, title: l10n.homeJoin, hint: l10n.homeJoinHint, onTap: openMain, fill: fill);

    final showTip = settings.shouldShowTip(_tipId);
    Widget tip({bool inRow = false}) => _Tip(
          text: presenterFirst ? l10n.homeTipPresent : l10n.homeTipJoin,
          onGotIt: markTipSeen,
          onSkip: () => settings.update((s) => s.tipsEnabled = false),
          inRow: inRow,
        );

    return Scaffold(
      backgroundColor: palette.ground,
      appBar: AppBar(
        backgroundColor: palette.ground,
        foregroundColor: palette.text,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EchoLogo(),
            const SizedBox(width: 10),
            Text(
              l10n.appTitle,
              style: theme.textTheme.titleLarge?.copyWith(color: palette.text, fontWeight: FontWeight.w600, letterSpacing: -0.3),
            ),
          ],
        ),
        actions: [
          if (account != null)
            IconButton(
              tooltip: account.isSignedIn ? l10n.account : l10n.signIn,
              icon: Icon(account.isSignedIn ? Icons.account_circle : Icons.login, color: palette.brand),
              onPressed: () => open(
                meetings != null
                    ? AccountScreen(account: account, meetings: meetings)
                    : SignInScreen(account: account),
              ),
            ),
          IconButton(
            tooltip: l10n.settings,
            icon: Icon(Icons.settings_outlined, color: palette.brand),
            onPressed: () => open(const SettingsScreen()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= _wideFrom;
            final side = wide ? ((constraints.maxWidth - _columnWidth) / 2).clamp(32.0, double.infinity) : 20.0;
            return ListView(
              padding: EdgeInsets.fromLTRB(side, wide ? 56 : 12, side, 32),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.homeTitle,
                    style: (wide ? theme.textTheme.headlineMedium : theme.textTheme.headlineSmall)
                        ?.copyWith(color: palette.text, fontWeight: FontWeight.w400, letterSpacing: -0.3),
                  ),
                ),
                SizedBox(height: wide ? 48 : 24),
                if (wide && showTip)
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
                  mainAction(),
                ],
                if (!presenterFirst) ...[
                  const SizedBox(height: 16),
                  _Elsewhere(
                    title: l10n.homeElsewhere,
                    rows: [
                      _ToolRow(icon: Icons.hearing, title: l10n.homeSounds, hint: l10n.homeSoundsHint, onTap: () => open(const SoundsScreen())),
                      _ToolRow(icon: Icons.forum_outlined, title: l10n.homeConversation, hint: l10n.homeConversationHint, onTap: () => open(const ConversationScreen())),
                      if (meetings != null)
                        _ToolRow(icon: Icons.history, title: l10n.homeHistory, hint: l10n.homeHistoryHint, onTap: () => open(HistoryScreen(meetings: meetings))),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    // No side padding, so the link's text starts on the panels' left edge.
                    style: EchoButtons.link(palette, flush: true),
                    onPressed: () => open(presenterFirst ? const JoinScreen() : const PresenterScreen()),
                    child: Text(presenterFirst ? l10n.homeOtherJoin : l10n.homeOtherPresent),
                  ),
                ),
              ],
            );
          },
        ),
      ),
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
    return Pressable(
      child: MergeSemantics(
      child: Semantics(
        button: true,
        child: Material(
          color: palette.accentTint,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: highContrast ? BorderSide(color: palette.border, width: 2) : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            highlightColor: palette.text.withValues(alpha: 0.05),
            hoverColor: palette.text.withValues(alpha: 0.03),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 32, color: palette.brand),
                      const Spacer(),
                      Icon(Icons.arrow_forward, color: palette.text),
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
    );
  }
}

/// The phone-only tools, grouped in one tonal panel so they never compete with the main action.
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
                  Icon(icon, size: 24, color: palette.muted),
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
                  Icon(Icons.chevron_right, color: palette.muted),
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
