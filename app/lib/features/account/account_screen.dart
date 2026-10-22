import 'package:flutter/material.dart';

import '../../core/account/account_service.dart';
import '../../core/history/meeting_store.dart';
import '../../core/org/org_store.dart';
import '../../core/services.dart';
import '../../l10n/app_localizations.dart';
import '../activity/activity_screen.dart';
import '../history/history_screen.dart';
import '../organization/org_screen.dart';

/// Who is signed in, the saved meetings, sign out and account deletion.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.account, required this.meetings});
  final AccountService account;
  final MeetingStore meetings;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _busy = false;

  Future<void> _leave(Future<void> Function() action) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await action();
      navigator.pop();
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e is LastAdminException ? l10n.orgLastAdmin : l10n.accountError)));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // The text is long; at large text sizes the whole dialog scrolls to its buttons.
        scrollable: true,
        icon: const Icon(Icons.warning_amber),
        title: Text(l10n.accountDeleteTitle),
        content: Text(l10n.accountDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.accountDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _leave(widget.account.deleteAccount);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final email = widget.account.user?.email ?? '';
    final services = ServicesScope.of(context);
    final organizations = services.organizations;
    final activity = services.activity;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.account)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Semantics(header: true, child: Text(l10n.accountSignedInAs(email), style: theme.textTheme.titleMedium)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(l10n.homeHistory),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => HistoryScreen(meetings: widget.meetings)),
              ),
            ),
            if (activity != null)
              ListTile(
                leading: const Icon(Icons.manage_history),
                title: Text(l10n.activityTitle),
                subtitle: Text(l10n.activityHint),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ActivityScreen(
                    title: l10n.activityTitle,
                    empty: l10n.activityEmpty,
                    me: widget.account.user?.id,
                    load: (before, rows) => activity.myActivity(beforeId: before, maxRows: rows),
                  ),
                )),
              ),
            if (organizations != null)
              ListTile(
                leading: const Icon(Icons.business),
                title: Text(l10n.orgTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  organizations.refresh();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrgScreen(organizations: organizations)));
                },
              ),
            const Divider(),
            ListTile(
              enabled: !_busy,
              leading: const Icon(Icons.logout),
              title: Text(l10n.accountSignOut),
              onTap: () => _leave(widget.account.signOut),
            ),
            ListTile(
              enabled: !_busy,
              leading: Icon(Icons.delete_forever, color: theme.colorScheme.error),
              title: Text(l10n.accountDelete),
              onTap: _confirmDelete,
            ),
            if (_busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}
