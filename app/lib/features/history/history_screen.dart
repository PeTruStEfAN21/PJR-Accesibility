import 'package:flutter/material.dart';

import '../../core/history/meeting_store.dart';
import '../../l10n/app_localizations.dart';
import 'saved_meeting_screen.dart';
import '../../widgets/page_column.dart';

/// "28 oct. 2026, 14:05" in the UI language.
String meetingDate(BuildContext context, DateTime date) {
  final material = MaterialLocalizations.of(context);
  return '${material.formatMediumDate(date)}, ${material.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
}

String meetingTitle(BuildContext context, SavedMeeting meeting) {
  final title = meeting.title?.trim() ?? '';
  return title.isNotEmpty ? title : AppLocalizations.of(context).historyUntitled(meetingDate(context, meeting.startedAt));
}

/// The signed-in user's saved meetings, newest first, with search.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.meetings});
  final MeetingStore meetings;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _search = TextEditingController();
  late Future<List<MeetingMatch>> _results;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _results = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<MeetingMatch>> _load() async {
    if (_query.isNotEmpty) return widget.meetings.search(_query);
    final meetings = await widget.meetings.listMeetings();
    return [for (final meeting in meetings) MeetingMatch(meeting: meeting)];
  }

  void _reload() {
    // Block body: an arrow would hand setState the Future, which it rejects.
    setState(() {
      _results = _load();
    });
  }

  void _runSearch(String text) {
    _query = text.trim();
    _reload();
  }

  void _clearSearch() {
    _search.clear();
    _runSearch('');
  }

  Future<void> _open(SavedMeeting meeting) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SavedMeetingScreen(meetings: widget.meetings, meeting: meeting)),
    );
    // The meeting may have been renamed.
    if (mounted) _reload();
  }

  Future<void> _confirmDelete(SavedMeeting meeting) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.historyDeleteTitle),
        content: Text(l10n.historyDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.historyDelete)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.meetings.deleteMeeting(meeting.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.historyDeleted)));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountError)));
    }
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeHistory)),
      body: PageColumn(child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: ListenableBuilder(
                listenable: _search,
                builder: (context, _) => TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    labelText: l10n.historySearchHint,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(tooltip: l10n.historyClearSearch, icon: const Icon(Icons.clear), onPressed: _clearSearch),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _runSearch,
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<MeetingMatch>>(
                future: _results,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _Message(
                      text: l10n.historyLoadError,
                      action: TextButton(onPressed: _reload, child: Text(l10n.retry)),
                    );
                  }
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final results = snapshot.data!;
                  if (results.isEmpty) {
                    return _Message(text: _query.isEmpty ? l10n.historyEmpty : l10n.historyNoResults(_query));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: results.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final match = results[i];
                      final meeting = match.meeting;
                      final title = meetingTitle(context, meeting);
                      return ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(title, style: theme.textTheme.titleMedium),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(meetingDate(context, meeting.startedAt)),
                            if (match.snippet case final snippet?)
                              Text('#${match.seq} · $snippet', maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                        trailing: IconButton(
                          tooltip: '${l10n.historyDelete}: $title',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDelete(meeting),
                        ),
                        onTap: () => _open(meeting),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      )),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            ?action,
          ],
        ),
      ),
    );
  }
}
