import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/org/org_store.dart';
import '../../core/org/organizations.dart';
import '../../core/services.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../../theme/echo_style.dart';
import '../../widgets/grouped_list.dart';
import '../activity/activity_screen.dart';
import '../alerts/alert_overlay.dart';
import '../alerts/sound_alert.dart';
import 'company_meetings_screen.dart';

/// "My company": invitations and creating a company when the user has none;
/// the employee's needs; for admins, employees, invitations and alarm roll calls.
class OrgScreen extends StatelessWidget {
  const OrgScreen({super.key, required this.organizations});
  final Organizations organizations;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: organizations,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.orgTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (organizations.invites.isNotEmpty) _Invites(organizations: organizations),
              if (!organizations.any) _CreateCompany(organizations: organizations),
              for (final m in organizations.memberships)
                m.isAdmin
                    ? _AdminView(key: ValueKey('admin-${m.orgId}'), organizations: organizations, membership: m)
                    : _EmployeeView(key: ValueKey('employee-${m.orgId}'), organizations: organizations, membership: m),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _header(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleLarge)),
    );

/// What the company sees about an employee, said before and after joining (GDPR art. 13).
Widget _privacyNote(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(child: Icon(Icons.info_outline)),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );

String _roleText(AppLocalizations l10n, OrgRole role) => role == OrgRole.admin ? l10n.orgRoleAdmin : l10n.orgRoleEmployee;

/// Runs a call against the database and reports a failure in a snack bar.
Future<bool> _attempt(BuildContext context, Future<void> Function() action) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  final failed = l10n.orgError;
  try {
    await action();
    return true;
  } on LastAdminException {
    messenger.showSnackBar(SnackBar(content: Text(l10n.orgLastAdmin)));
    return false;
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(failed)));
    return false;
  }
}

class _Invites extends StatelessWidget {
  const _Invites({required this.organizations});
  final Organizations organizations;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, l10n.orgInvitesTitle),
        for (final invite in organizations.invites)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.orgInviteFrom(invite.orgName), style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(_roleText(l10n, invite.role)),
                  _privacyNote(context, l10n.orgInviteNotice),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () async {
                      if (await _attempt(context, () => organizations.store.acceptInvite(invite.id))) {
                        await organizations.refresh();
                      }
                    },
                    child: Text(l10n.orgAccept),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CreateCompany extends StatefulWidget {
  const _CreateCompany({required this.organizations});
  final Organizations organizations;

  @override
  State<_CreateCompany> createState() => _CreateCompanyState();
}

class _CreateCompanyState extends State<_CreateCompany> {
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    final ok = await _attempt(context, () => widget.organizations.store.createOrganization(_name.text));
    if (ok) await widget.organizations.refresh();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.orgNone, style: theme.textTheme.titleMedium),
        _header(context, l10n.orgCreateTitle),
        Text(l10n.orgCreateHint),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          maxLength: 200,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: l10n.orgName),
          onChanged: (_) => setState(() {}),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _busy || _name.text.trim().isEmpty ? null : _create,
          child: Text(l10n.orgCreate),
        ),
      ],
    );
  }
}

/// What the employee shares, and leaving the company.
class _EmployeeView extends StatefulWidget {
  const _EmployeeView({super.key, required this.organizations, required this.membership});
  final Organizations organizations;
  final OrgMembership membership;

  @override
  State<_EmployeeView> createState() => _EmployeeViewState();
}

class _EmployeeViewState extends State<_EmployeeView> {
  MemberNeeds _needs = const MemberNeeds();

  OrgStore get _store => widget.organizations.store;
  String get _userId => widget.organizations.account.user!.id;

  @override
  void initState() {
    super.initState();
    _store.loadNeeds(widget.membership.orgId, _userId).then((saved) {
      if (saved != null && mounted) setState(() => _needs = saved);
    }, onError: (Object _) {});
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final needs = _needs.copyWith(language: SettingsScope.of(context).speechLanguage);
    if (await _attempt(context, () => _store.saveNeeds(widget.membership.orgId, _userId, needs))) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.orgSaved)));
    }
  }

  Future<void> _leave() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.orgLeaveTitle(widget.membership.orgName)),
        content: Text(l10n.orgLeaveBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.orgLeave)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (await _attempt(context, () => _store.leave(widget.membership.orgId, _userId))) {
      await widget.organizations.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.membership.orgName, style: theme.textTheme.headlineSmall),
        Text(_roleText(l10n, widget.membership.role)),
        _privacyNote(context, l10n.orgEmployeeNotice),
        _header(context, l10n.orgMyNeeds),
        Text(l10n.orgMyNeedsHint),
        SwitchListTile(
          title: Text(l10n.needCaptions),
          value: _needs.captions,
          onChanged: (v) => setState(() => _needs = _needs.copyWith(captions: v)),
        ),
        SwitchListTile(
          title: Text(l10n.needVisualAlerts),
          value: _needs.visualAlerts,
          onChanged: (v) => setState(() => _needs = _needs.copyWith(visualAlerts: v)),
        ),
        SwitchListTile(
          title: Text(l10n.needWatchAlerts),
          value: _needs.watchAlerts,
          onChanged: (v) => setState(() => _needs = _needs.copyWith(watchAlerts: v)),
        ),
        SwitchListTile(
          title: Text(l10n.needLargeText),
          value: _needs.largeText,
          onChanged: (v) => setState(() => _needs = _needs.copyWith(largeText: v)),
        ),
        const SizedBox(height: 8),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _save,
          child: Text(l10n.orgSave),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _leave,
          icon: const Icon(Icons.logout),
          label: Text(l10n.orgLeave),
        ),
      ],
    );
  }
}

/// Needs in words (never colour or icons alone).
String _needsText(AppLocalizations l10n, MemberNeeds? needs) {
  if (needs == null) return l10n.orgNeedsNotShared;
  return [
    if (needs.captions) l10n.needCaptions,
    if (needs.visualAlerts) l10n.needVisualAlerts,
    if (needs.watchAlerts) l10n.needWatchAlerts,
    if (needs.largeText) l10n.needLargeText,
  ].join(' · ');
}

/// Employees, invitations and the roll call of open alarms (refreshed every 5 s).
class _AdminView extends StatefulWidget {
  const _AdminView({super.key, required this.organizations, required this.membership});
  final Organizations organizations;
  final OrgMembership membership;

  @override
  State<_AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<_AdminView> {
  static const _alarmRefresh = Duration(seconds: 5);

  final _email = TextEditingController();
  final _department = TextEditingController();
  List<OrgMember> _members = const [];
  List<PendingInvite> _pending = const [];
  List<(AlarmEvent, List<AlarmAnswer>)> _alarms = const [];
  Timer? _timer;

  OrgStore get _store => widget.organizations.store;
  String get _orgId => widget.membership.orgId;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(_alarmRefresh, (_) => _loadAlarms());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _department.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final members = await _store.members(_orgId);
      final pending = await _store.pendingInvites(_orgId);
      if (!mounted) return;
      setState(() {
        _members = members;
        _pending = pending;
      });
      await _loadAlarms();
    } catch (e) {
      debugPrint('Company not loaded: $e');
    }
  }

  Future<void> _loadAlarms() async {
    try {
      final events = await _store.openAlarms(_orgId);
      final alarms = [for (final e in events) (e, await _store.alarmAnswers(e.id))];
      if (mounted) setState(() => _alarms = alarms);
    } catch (e) {
      debugPrint('Alarms not loaded: $e');
    }
  }

  Future<void> _change(Future<void> Function() action) async {
    if (await _attempt(context, action)) await _load();
  }

  Future<void> _invite() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final email = _email.text.trim();
    if (!email.contains('@')) return;
    final ok = await _attempt(context, () => _store.invite(_orgId, email, department: _department.text));
    if (!ok) return;
    _email.clear();
    _department.clear();
    messenger.showSnackBar(SnackBar(content: Text(l10n.orgInviteSent)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final me = widget.organizations.account.user?.id;
    final activity = ServicesScope.of(context).activity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.membership.orgName, style: theme.textTheme.headlineSmall),
        Text(_roleText(l10n, widget.membership.role)),
        // Admins' own meetings saved for the company are readable by the other admins too.
        _privacyNote(context, l10n.orgEmployeeNotice),
        const SizedBox(height: 24),
        _JoinCodeSection(store: _store, orgId: _orgId),

        _header(context, l10n.orgAlarms),
        if (_alarms.isEmpty) Text(l10n.orgNoAlarms),
        for (final (event, answers) in _alarms) _rollCall(context, event, answers),

        _header(context, l10n.orgMembers),
        for (final member in _members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(member.role == OrgRole.admin ? Icons.admin_panel_settings : Icons.person_outline),
            title: Text(member.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // How they use Echo: icon + text, never colour alone.
                Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        member.experience == MemberExperience.visual
                            ? Icons.closed_caption_outlined
                            : Icons.record_voice_over_outlined,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(member.experience == MemberExperience.visual ? l10n.memberReads : l10n.memberHears),
                    ),
                  ],
                ),
                Text([
                  _roleText(l10n, member.role),
                  if (member.department != null) member.department!,
                  _needsText(l10n, member.needs),
                ].where((part) => part.isNotEmpty).join('\n')),
              ],
            ),
            isThreeLine: true,
            trailing: member.userId == me
                ? null
                : PopupMenuButton<String>(
                    onSelected: (action) => _change(() => switch (action) {
                          'admin' => _store.setRole(_orgId, member.userId, OrgRole.admin),
                          'employee' => _store.setRole(_orgId, member.userId, OrgRole.employee),
                          _ => _store.removeMember(_orgId, member.userId),
                        }),
                    itemBuilder: (context) => [
                      if (member.role == OrgRole.employee)
                        PopupMenuItem(value: 'admin', child: Text(l10n.orgMakeAdmin))
                      else
                        PopupMenuItem(value: 'employee', child: Text(l10n.orgMakeEmployee)),
                      PopupMenuItem(value: 'remove', child: Text(l10n.orgRemove)),
                    ],
                  ),
          ),

        _header(context, l10n.orgInvite),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(labelText: l10n.orgEmail),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _department,
          maxLength: 100,
          decoration: InputDecoration(labelText: l10n.orgDepartment),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _invite,
          child: Text(l10n.orgSendInvite),
        ),

        if (_pending.isNotEmpty) ...[
          _header(context, l10n.orgPending),
          for (final invite in _pending)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.mail_outline),
              title: Text(invite.email),
              subtitle: Text([_roleText(l10n, invite.role), ?invite.department].join(' · ')),
              trailing: IconButton(
                tooltip: l10n.orgCancelInvite,
                icon: const Icon(Icons.close),
                onPressed: () => _change(() => _store.cancelInvite(invite.id)),
              ),
            ),
        ],

        if (activity != null) ...[
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history),
            title: Text(l10n.orgHistory),
            subtitle: Text(l10n.orgHistoryHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ActivityScreen(
                title: l10n.orgHistory,
                empty: l10n.activityCompanyEmpty,
                me: me,
                load: (before, rows) => activity.companyActivity(_orgId, beforeId: before, maxRows: rows),
              ),
            )),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.orgMeetings),
            subtitle: Text(l10n.orgMeetingsHint),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CompanyMeetingsScreen(store: activity, orgId: _orgId, me: me),
            )),
          ),
        ],
      ],
    );
  }

  Widget _rollCall(BuildContext context, AlarmEvent event, List<AlarmAnswer> answers) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final kind = SoundKind.values.asNameMap()[event.kind];
    final byUser = {for (final a in answers) a.userId: a.status};
    final names = {for (final m in _members) m.userId: m.name};
    final needHelp = [for (final a in answers) if (a.status == AlarmAnswerStatus.needHelp) names[a.userId] ?? a.userId];
    final safe = byUser.values.where((s) => s == AlarmAnswerStatus.safe).length;
    final noAnswer = _members.where((m) => !byUser.containsKey(m.userId)).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(kind != null ? soundIcon(kind) : Icons.warning_amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kind != null ? soundLabel(l10n, kind) : event.kind,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.orgAlarmHelp(needHelp.length), style: theme.textTheme.titleMedium),
            for (final name in needHelp) Text('• $name'),
            const SizedBox(height: 4),
            Text(l10n.orgAlarmSafe(safe)),
            Text(l10n.orgAlarmNoAnswer(noAnswer.length)),
            for (final m in noAnswer) Text('• ${m.name}'),
            const SizedBox(height: 8),
            Text(l10n.orgRollCallNote, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () async {
                if (await _attempt(context, () => _store.closeAlarm(event.id))) await _loadAlarms();
              },
              child: Text(l10n.orgCloseAlarm),
            ),
          ],
        ),
      ),
    );
  }
}

/// The company code: made here, shown once (the database keeps only its fingerprint), copied and
/// handed to colleagues, who join with it from Sign in → Employee.
class _JoinCodeSection extends StatefulWidget {
  const _JoinCodeSection({required this.store, required this.orgId});
  final OrgStore store;
  final String orgId;

  @override
  State<_JoinCodeSection> createState() => _JoinCodeSectionState();
}

class _JoinCodeSectionState extends State<_JoinCodeSection> {
  DateTime? _expires;
  String? _shown;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.store.joinCodeInfo(widget.orgId).then((expires) {
      if (mounted) setState(() => _expires = expires);
    }, onError: (Object e) => debugPrint('Company code not loaded: $e'));
  }

  Future<void> _make() async {
    setState(() => _busy = true);
    String? code;
    final ok = await _attempt(context, () async => code = await widget.store.newJoinCode(widget.orgId));
    final expires = ok ? await widget.store.joinCodeInfo(widget.orgId).catchError((Object _) => null) : _expires;
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _shown = code;
      _expires = expires;
    });
  }

  Future<void> _revoke() async {
    setState(() => _busy = true);
    final ok = await _attempt(context, () => widget.store.revokeJoinCode(widget.orgId));
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _shown = null;
        _expires = null;
      }
    });
  }

  Future<void> _copy() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _shown!));
    messenger.showSnackBar(SnackBar(content: Text(l10n.orgCodeCopied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = EchoPalette.of(context);
    final shown = _shown;
    final expires = _expires;
    final localizations = MaterialLocalizations.of(context);
    String until(DateTime d) =>
        '${localizations.formatMediumDate(d)}, ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(d))}';

    return EchoGroup(
      title: l10n.orgCodeTitle,
      footer: Text(l10n.orgCodeHint),
      rows: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (shown != null) ...[
                Text(l10n.orgCodeShown, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        // Read letter by letter, as it will be typed.
                        label: shown.split('').join(' '),
                        excludeSemantics: true,
                        child: Text(
                          shown,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 3,
                            color: palette.text,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.orgCodeCopy,
                      onPressed: _copy,
                      icon: Icon(Icons.copy_rounded, color: palette.accent),
                    ),
                  ],
                ),
                if (expires != null) Text(l10n.orgCodeActiveUntil(until(expires)), style: theme.textTheme.bodyMedium),
              ] else
                Text(
                  expires != null ? l10n.orgCodeActiveUntil(until(expires)) : l10n.orgCodeNone,
                  style: theme.textTheme.bodyLarge,
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: _busy ? null : _make,
                icon: const Icon(Icons.vpn_key_outlined),
                label: Text(l10n.orgCodeNew),
              ),
              if (expires != null || shown != null)
                TextButton(onPressed: _busy ? null : _revoke, child: Text(l10n.orgCodeRevoke)),
            ],
          ),
        ),
      ],
    );
  }
}
