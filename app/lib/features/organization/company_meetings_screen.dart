import 'package:flutter/material.dart';

import '../../core/org/activity_store.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/caption_tile.dart';
import '../history/history_screen.dart';
import '../history/saved_meeting_screen.dart';
import '../../widgets/page_column.dart';

/// A short note with an icon, above a list.
class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(Icons.visibility_outlined, color: theme.colorScheme.onSecondaryContainer)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSecondaryContainer)),
          ),
        ],
      ),
    );
  }
}

/// For a company's admins: the meetings employees saved for it. Listing reads
/// nothing; opening one is logged in the employee's history, which the screen says first.
class CompanyMeetingsScreen extends StatefulWidget {
  const CompanyMeetingsScreen({super.key, required this.store, required this.orgId, this.me});
  final ActivityStore store;
  final String orgId;
  final String? me;

  @override
  State<CompanyMeetingsScreen> createState() => _CompanyMeetingsScreenState();
}

class _CompanyMeetingsScreenState extends State<CompanyMeetingsScreen> {
  late Future<List<CompanyMeeting>> _meetings = widget.store.companyMeetings(widget.orgId);

  void _reload() {
    setState(() {
      _meetings = widget.store.companyMeetings(widget.orgId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.orgMeetings)),
      body: PageColumn(child: SafeArea(
        child: FutureBuilder<List<CompanyMeeting>>(
          future: _meetings,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.orgMeetingsLoadError, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                      TextButton(onPressed: _reload, child: Text(l10n.retry)),
                    ],
                  ),
                ),
              );
            }
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final meetings = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: meetings.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Notice(text: l10n.orgMeetingsNotice),
                        if (meetings.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Text(l10n.orgMeetingsEmpty, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                          ),
                      ],
                    ),
                  );
                }
                final item = meetings[i - 1];
                return ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(meetingTitle(context, item.meeting), style: theme.textTheme.titleMedium),
                  subtitle: Text([?item.ownerEmail, meetingDate(context, item.meeting.startedAt)].join(' · ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CompanyMeetingScreen(store: widget.store, item: item, me: widget.me)),
                  ),
                );
              },
            );
          },
        ),
      )),
    );
  }
}

/// One company meeting, read-only: summary, tasks and the numbered transcript.
/// Loaded once, when the admin opens it: the database logs this reading.
class CompanyMeetingScreen extends StatefulWidget {
  const CompanyMeetingScreen({super.key, required this.store, required this.item, this.me});
  final ActivityStore store;
  final CompanyMeeting item;
  final String? me;

  @override
  State<CompanyMeetingScreen> createState() => _CompanyMeetingScreenState();
}

class _CompanyMeetingScreenState extends State<CompanyMeetingScreen> {
  late Future<CompanyMeetingContent> _content = widget.store.companyMeeting(widget.item.meeting.id);

  void _retry() {
    setState(() {
      _content = widget.store.companyMeeting(widget.item.meeting.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ownMeeting = widget.me != null && widget.item.ownerId == widget.me;
    return Scaffold(
      appBar: AppBar(title: Text(meetingTitle(context, widget.item.meeting))),
      body: PageColumn(child: SafeArea(
        child: FutureBuilder<CompanyMeetingContent>(
          future: _content,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.orgMeetingLoadError, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                      TextButton(onPressed: _retry, child: Text(l10n.retry)),
                    ],
                  ),
                ),
              );
            }
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final content = snapshot.data!;
            final owner = content.ownerEmail ?? widget.item.ownerEmail;
            final summary = content.summary;
            final header = [
              if (!ownMeeting)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _Notice(text: l10n.orgMeetingReadNotice(owner ?? l10n.orgMeetingOwnerUnknown)),
                ),
              Text([?owner, meetingDate(context, content.meeting.startedAt)].join(' · '), style: theme.textTheme.bodyMedium),
              if (summary != null) MeetingSummaryCard(summary: summary),
              if (content.lines.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(l10n.transcriptEmpty)),
            ];
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: header.length + content.lines.length,
              itemBuilder: (_, i) {
                if (i < header.length) return header[i];
                final line = content.lines[i - header.length];
                return CaptionTile(caption: line.toCaption(content.lang), number: line.seq);
              },
            );
          },
        ),
      )),
    );
  }
}
