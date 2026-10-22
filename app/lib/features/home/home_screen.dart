import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../l10n/app_localizations.dart';
import '../account/account_screen.dart';
import '../account/sign_in_screen.dart';
import '../conversation/conversation_screen.dart';
import '../history/history_screen.dart';
import '../participant/join_screen.dart';
import '../presenter/presenter_screen.dart';
import '../settings/settings_screen.dart';
import '../sounds/sounds_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final account = ServicesScope.of(context).account;
    // Accounts are optional: without Supabase configured the home screen is unchanged.
    if (account == null) return _build(context);
    return ListenableBuilder(listenable: account, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final services = ServicesScope.of(context);
    final account = services.account;
    final meetings = services.signedInMeetings;
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          if (account != null)
            IconButton(
              tooltip: account.isSignedIn ? l10n.account : l10n.signIn,
              icon: Icon(account.isSignedIn ? Icons.account_circle : Icons.login),
              onPressed: () => open(
                meetings != null
                    ? AccountScreen(account: account, meetings: meetings)
                    : SignInScreen(account: account),
              ),
            ),
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings),
            onPressed: () => open(const SettingsScreen()),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Semantics(
              header: true,
              child: Text(l10n.homeTitle, style: Theme.of(context).textTheme.headlineSmall),
            ),
            const SizedBox(height: 16),
            _ModeCard(icon: Icons.closed_caption, title: l10n.homeJoin, hint: l10n.homeJoinHint, onTap: () => open(const JoinScreen())),
            _ModeCard(icon: Icons.co_present, title: l10n.homePresent, hint: l10n.homePresentHint, onTap: () => open(const PresenterScreen())),
            _ModeCard(icon: Icons.hearing, title: l10n.homeSounds, hint: l10n.homeSoundsHint, onTap: () => open(const SoundsScreen())),
            _ModeCard(icon: Icons.forum, title: l10n.homeConversation, hint: l10n.homeConversationHint, onTap: () => open(const ConversationScreen())),
            if (meetings != null)
              _ModeCard(
                icon: Icons.history,
                title: l10n.homeHistory,
                hint: l10n.homeHistoryHint,
                onTap: () => open(HistoryScreen(meetings: meetings)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.icon, required this.title, required this.hint, required this.onTap});

  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, size: 40, color: theme.colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(hint, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
