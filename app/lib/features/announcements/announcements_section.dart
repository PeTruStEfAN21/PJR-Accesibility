import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/org/org_store.dart';
import '../../core/org/organizations.dart';
import '../../core/services.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/echo_style.dart';
import '../../widgets/grouped_list.dart';

/// The company's announcements on the Dashboard (phone) and under the main action (laptop):
/// docs/superpowers/specs/2026-10-23-anunturi-design.md. Hidden for anyone in no company.
///
/// Kept plain, like the grouped lists in Settings: one row per announcement (title, two lines of
/// text, date), a small dot for a new one, the word Important where it applies. The whole text opens
/// on tap, which counts as seen; there the admin sees how many saw it and can delete it.
class AnnouncementsSection extends StatefulWidget {
  const AnnouncementsSection({super.key, this.first = false});

  /// The first thing on the page (the phone's Dashboard): no space above, a little below.
  final bool first;

  /// Often enough that a new announcement reaches the phones during a demo.
  static const refreshEvery = Duration(seconds: 30);

  @override
  State<AnnouncementsSection> createState() => _AnnouncementsSectionState();
}

/// The admin's form, from the Dashboard or from Compania mea; true once posted.
Future<bool> showComposeAnnouncement(BuildContext context, List<OrgMembership> companies, OrgStore store) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ComposeSheet(companies: companies, store: store),
    ) ??
    false;

class _AnnouncementsSectionState extends State<AnnouncementsSection> {
  Organizations? _organizations;
  List<Announcement> _items = const [];
  Map<String, AnnouncementSeen> _seenCounts = const {};
  Timer? _timer;

  /// The first answer came: until then the list is not said to be empty.
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final organizations = ServicesScope.of(context).organizations;
    if (identical(organizations, _organizations)) return;
    _organizations?.removeListener(_load);
    _organizations = organizations;
    organizations?.addListener(_load);
    _timer?.cancel();
    if (organizations != null) _timer = Timer.periodic(AnnouncementsSection.refreshEvery, (_) => _load());
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _organizations?.removeListener(_load);
    super.dispose();
  }

  List<OrgMembership> get _adminOf => [...?_organizations?.memberships.where((m) => m.isAdmin)];
  bool _isAdminOf(String orgId) => _adminOf.any((m) => m.orgId == orgId);

  Future<void> _load() async {
    final organizations = _organizations;
    if (organizations == null || !organizations.any) {
      if (mounted && _items.isNotEmpty) setState(() => _items = const []);
      return;
    }
    try {
      final items = await organizations.store.announcements();
      final counts = <String, AnnouncementSeen>{};
      for (final m in _adminOf) {
        counts.addAll(await organizations.store.announcementSeen(m.orgId));
      }
      items.sort((a, b) => a.important != b.important ? (a.important ? -1 : 1) : b.createdAt.compareTo(a.createdAt));
      if (mounted) {
        setState(() {
          _items = items;
          _seenCounts = counts;
          _loaded = true;
        });
      }
    } catch (e) {
      debugPrint('Announcements not loaded: $e');
    }
  }

  /// Opening it is seeing it; the admin's own company's announcements show the count instead.
  Future<void> _open(Announcement a) async {
    final admin = _isAdminOf(a.orgId);
    if (!admin && !a.seen) {
      setState(() => _items = [for (final x in _items) x.id == a.id ? _seen(x) : x]);
      unawaited(
        _organizations!.store.markAnnouncementSeen(a.id).catchError((Object e) {
          debugPrint('Announcement not marked seen: $e');
        }),
      );
    }
    final deleted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AnnouncementSheet(
        announcement: a,
        seenCount: admin ? (_seenCounts[a.id] ?? (seen: 0, audience: 0)) : null,
        store: _organizations!.store,
      ),
    );
    if (deleted == true) await _load();
  }

  Announcement _seen(Announcement a) => Announcement(
    id: a.id,
    orgId: a.orgId,
    orgName: a.orgName,
    title: a.title,
    body: a.body,
    important: a.important,
    createdAt: a.createdAt,
    seen: true,
  );

  @override
  Widget build(BuildContext context) {
    final organizations = _organizations;
    if (organizations == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: organizations,
      builder: (context, _) {
        if (!organizations.any) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context);
        final theme = Theme.of(context);
        final palette = EchoPalette.of(context);
        final admins = _adminOf;
        final unread = _items.where((a) => !a.seen && !_isAdminOf(a.orgId)).length;
        return Padding(
          padding: widget.first ? const EdgeInsets.only(top: 4, bottom: 24) : const EdgeInsets.only(top: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 4),
                      // The count is said with the heading as a sentence ("1 anunț nou"), not shown as a badge.
                      child: Semantics(
                        header: true,
                        value: unread > 0 ? l10n.announcementsNew(unread) : null,
                        child: Text(
                          l10n.announcementsTitle,
                          style: theme.textTheme.titleLarge?.copyWith(color: palette.text, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  if (admins.isNotEmpty)
                    TextButton.icon(
                      onPressed: () async {
                        if (await showComposeAnnouncement(context, admins, organizations.store)) await _load();
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.composeTitle),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_items.isNotEmpty || _loaded)
                EchoGroup(
                  rows: _items.isEmpty
                      ? [
                          // The place for the mascot later: a friendly word instead of a blank list.
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                            child: Text(
                              admins.isNotEmpty ? l10n.announcementsEmptyAdmin : l10n.announcementsEmpty,
                              style: theme.textTheme.bodyLarge?.copyWith(color: palette.muted),
                            ),
                          ),
                        ]
                      : [
                          for (final a in _items)
                            _AnnouncementRow(
                              key: ValueKey(a.id),
                              announcement: a,
                              isNew: !a.seen && !_isAdminOf(a.orgId),
                              onTap: () => _open(a),
                            ),
                        ],
                ),
            ],
          ),
        );
      },
    );
  }
}

String _when(BuildContext context, DateTime at) {
  final material = MaterialLocalizations.of(context);
  return '${material.formatShortMonthDay(at)}, ${material.formatTimeOfDay(TimeOfDay.fromDateTime(at))}';
}

class _AnnouncementRow extends StatelessWidget {
  const _AnnouncementRow({super.key, required this.announcement, required this.isNew, required this.onTap});
  final Announcement announcement;
  final bool isNew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = EchoPalette.of(context);
    final a = announcement;
    return MergeSemantics(
      child: Semantics(
        button: true,
        label: isNew ? l10n.announcementNew : null,
        child: InkWell(
          onTap: onTap,
          splashFactory: NoSplash.splashFactory,
          highlightColor: palette.text.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // New: a small dot, also said as "Nou"; it goes once the announcement is opened.
                SizedBox(
                  width: 16,
                  height: 22,
                  child: isNew
                      ? Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: palette.accent, shape: BoxShape.circle),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: palette.text,
                          fontWeight: isNew ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        a.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (a.important)
                            Text(
                              l10n.announcementImportant,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: palette.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          Text(
                            _when(context, a.createdAt),
                            style: theme.textTheme.labelMedium?.copyWith(color: palette.muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ExcludeSemantics(child: Icon(Icons.chevron_right_rounded, color: palette.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The whole announcement. For the company's admins: how many saw it, and deleting it (closes with true).
class _AnnouncementSheet extends StatelessWidget {
  const _AnnouncementSheet({required this.announcement, required this.seenCount, required this.store});
  final Announcement announcement;
  final AnnouncementSeen? seenCount;
  final OrgStore store;

  Future<void> _delete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.announcementDeleteTitle),
        content: Text(l10n.announcementDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(l10n.announcementDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await store.deleteAnnouncement(announcement.id);
      navigator.pop(true);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.orgError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = EchoPalette.of(context);
    final a = announcement;
    final counts = seenCount;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        children: [
          Text(
            [if (a.important) l10n.announcementImportant, a.orgName, _when(context, a.createdAt)].join(' · '),
            style: theme.textTheme.labelMedium?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text(
              a.title,
              style: theme.textTheme.titleLarge?.copyWith(color: palette.text, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          Text(a.body, style: theme.textTheme.bodyLarge?.copyWith(color: palette.text)),
          if (counts != null) ...[
            const SizedBox(height: 24),
            Divider(height: 1, color: palette.border),
            const SizedBox(height: 12),
            Text(
              l10n.announcementSeenBy(counts.seen, counts.audience),
              style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                // Destructive: red, away from everything else (it asks first).
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                ),
                onPressed: () => _delete(context),
                child: Text(l10n.announcementDelete),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Title, message and Important; it shows for a week.
class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({required this.companies, required this.store});
  final List<OrgMembership> companies;
  final OrgStore store;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  static const _days = 7;

  final _title = TextEditingController();
  final _body = TextEditingController();
  late String _orgId = widget.companies.first.orgId;
  bool _important = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      setState(() => _error = l10n.composeMissing);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.postAnnouncement(
        _orgId,
        title: _title.text,
        body: _body.text,
        important: _important,
        days: _days,
      );
      navigator.pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l10n.orgError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = EchoPalette.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Semantics(
              header: true,
              child: Text(l10n.composeTitle, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: 20),
            if (widget.companies.length > 1) ...[
              DropdownButtonFormField<String>(
                initialValue: _orgId,
                decoration: InputDecoration(labelText: l10n.composeCompany),
                items: [for (final m in widget.companies) DropdownMenuItem(value: m.orgId, child: Text(m.orgName))],
                onChanged: (value) => setState(() => _orgId = value ?? _orgId),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _title,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.composeTitleLabel),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _body,
              maxLength: 2000,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.composeBodyLabel, alignLabelWithHint: true),
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              value: _important,
              onChanged: (value) => setState(() => _important = value),
              activeTrackColor: palette.accent,
              title: Text(l10n.composeImportant),
              subtitle: Text(l10n.composeImportantHint),
            ),
            const SizedBox(height: 8),
            // Who sees it, and what not to write (GDPR art. 13 and data minimisation).
            Text(l10n.composePrivacy, style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted)),
            if (_error case final error?) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
                    const SizedBox(width: 10),
                    Expanded(child: Text(error, style: theme.textTheme.bodyLarge)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _busy ? null : _publish,
              child: Text(l10n.composePublish),
            ),
          ],
        ),
      ),
    );
  }
}
