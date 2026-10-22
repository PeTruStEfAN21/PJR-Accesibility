import 'package:flutter/material.dart';

import '../../core/history/meeting_store.dart';
import '../../core/server_api.dart';
import '../../core/services.dart';
import '../../core/transcript.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../../widgets/caption_tile.dart';
import '../participant/meeting_ai.dart';
import 'history_screen.dart';

/// One saved meeting: its summary (if made), the numbered transcript, and the
/// same summary and "Întreabă meetingul" tools as during the meeting.
class SavedMeetingScreen extends StatefulWidget {
  const SavedMeetingScreen({super.key, required this.meetings, required this.meeting});
  final MeetingStore meetings;
  final SavedMeeting meeting;

  @override
  State<SavedMeetingScreen> createState() => _SavedMeetingScreenState();
}

class _SavedMeetingScreenState extends State<SavedMeetingScreen> {
  final _transcript = Transcript();
  late SavedMeeting _meeting = widget.meeting;
  MeetingSummary? _summary;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _transcript.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _loading = true;
      _failed = false;
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final (lines, summary) = (
        await widget.meetings.loadLines(_meeting.id),
        await widget.meetings.loadSummary(_meeting.id),
      );
      if (!mounted) return;
      _transcript.clear();
      for (final line in lines) {
        _transcript.upsert(line.toCaption(''));
      }
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } on Object {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  ServerApi _api() => ServicesScope.of(context).api(defaultServer(SettingsScope.of(context)));

  Future<void> _saveSummary(MeetingSummary summary, String lang) async {
    if (mounted) setState(() => _summary = summary);
    try {
      await widget.meetings.saveSummary(_meeting.id, summary, lang);
    } on Object catch (error) {
      debugPrint('Saving the summary failed: $error');
    }
  }

  Future<void> _rename() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: _meeting.title ?? ''),
    );
    if (title == null) return;
    try {
      await widget.meetings.renameMeeting(_meeting.id, title);
      final trimmed = title.trim();
      if (mounted) {
        setState(() => _meeting = SavedMeeting(
              id: _meeting.id,
              title: trimmed.isEmpty ? null : trimmed,
              startedAt: _meeting.startedAt,
              endedAt: _meeting.endedAt,
            ));
      }
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.accountError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(meetingTitle(context, _meeting)),
        actions: [
          IconButton(tooltip: l10n.meetingRename, icon: const Icon(Icons.edit_outlined), onPressed: _rename),
          PopupMenuButton<String>(
            enabled: !_loading && !_failed,
            onSelected: (value) {
              if (value == 'summary') showSummarySheet(context, _api(), _transcript, onSummary: _saveSummary);
              if (value == 'ask') openAskScreen(context, _api(), _transcript);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'summary', child: Text(l10n.summaryAction)),
              PopupMenuItem(value: 'ask', child: Text(l10n.askAction)),
            ],
          ),
        ],
      ),
      body: SafeArea(child: _body(context, l10n)),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.historyLoadError, textAlign: TextAlign.center),
            TextButton(onPressed: _retry, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    final captions = _transcript.captions;
    final numbers = _transcript.finalNumbers();
    final summary = _summary;
    final header = [
      Text(meetingDate(context, _meeting.startedAt), style: Theme.of(context).textTheme.bodyMedium),
      if (summary != null) MeetingSummaryCard(summary: summary),
      if (captions.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(l10n.transcriptEmpty)),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: header.length + captions.length,
      itemBuilder: (_, i) {
        if (i < header.length) return header[i];
        final caption = captions[i - header.length];
        return CaptionTile(caption: caption, number: numbers[caption.id]);
      },
    );
  }
}

/// A meeting's summary and tasks, as saved.
class MeetingSummaryCard extends StatelessWidget {
  const MeetingSummaryCard({super.key, required this.summary});
  final MeetingSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(l10n.summaryTitle, style: theme.textTheme.titleLarge)),
            const SizedBox(height: 8),
            Text(summary.summary, style: theme.textTheme.bodyLarge),
            if (summary.tasks.isNotEmpty) ...[
              const SizedBox(height: 16),
              Semantics(header: true, child: Text(l10n.summaryTasks, style: theme.textTheme.titleMedium)),
              for (final task in summary.tasks)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_box_outline_blank),
                  title: Text(task.text),
                  subtitle: task.owner == null ? null : Text(l10n.summaryOwner(task.owner!)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Owns its text controller, so it outlives the dialog's closing animation.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});
  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.meetingRename),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 200,
        decoration: InputDecoration(labelText: l10n.meetingNameLabel),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: Text(l10n.save)),
      ],
    );
  }
}
