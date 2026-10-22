import 'package:flutter/material.dart';

import '../../core/protocol.dart';
import '../../core/server_api.dart';
import '../../core/transcript.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/caption_tile.dart';

String _lang(BuildContext context) => Localizations.localeOf(context).languageCode;

void _showEmpty(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).transcriptEmpty)));
}

/// Summary and task list of the meeting so far.
void showSummarySheet(BuildContext context, ServerApi api, Transcript transcript) {
  final lines = transcript.finalLines();
  if (lines.isEmpty) return _showEmpty(context);
  final future = api.summarize(_lang(context), lines);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      final theme = Theme.of(context);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, scroll) => FutureBuilder<MeetingSummary>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError) return _AiError(message: l10n.aiError);
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final summary = snapshot.data!;
            return ListView(
              controller: scroll,
              padding: const EdgeInsets.all(20),
              children: [
                Semantics(header: true, child: Text(l10n.summaryTitle, style: theme.textTheme.headlineSmall)),
                const SizedBox(height: 12),
                Text(summary.summary, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 24),
                Semantics(header: true, child: Text(l10n.summaryTasks, style: theme.textTheme.titleLarge)),
                if (summary.tasks.isEmpty) Text(l10n.summaryNoTasks),
                for (final task in summary.tasks)
                  ListTile(
                    leading: const Icon(Icons.check_box_outline_blank),
                    title: Text(task.text),
                    subtitle: task.owner == null ? null : Text(l10n.summaryOwner(task.owner!)),
                  ),
                const SizedBox(height: 16),
                Text(l10n.summaryPrivacy, style: theme.textTheme.bodySmall),
              ],
            );
          },
        ),
      );
    },
  );
}

/// "Întreabă meetingul": questions answered by the server-side agent, with the
/// cited transcript lines shown under each answer.
void openAskScreen(BuildContext context, ServerApi api, Transcript transcript) {
  if (transcript.finalLines().isEmpty) return _showEmpty(context);
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _AskScreen(api: api, transcript: transcript),
    ),
  );
}

class _AskScreen extends StatefulWidget {
  const _AskScreen({required this.api, required this.transcript});
  final ServerApi api;
  final Transcript transcript;

  @override
  State<_AskScreen> createState() => _AskScreenState();
}

class _Exchange {
  _Exchange(this.question);
  final String question;
  MeetingAnswer? answer;
  bool failed = false;
}

class _AskScreenState extends State<_AskScreen> {
  final _question = TextEditingController();
  final _exchanges = <_Exchange>[];
  bool _busy = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final text = _question.text.trim();
    if (text.isEmpty || _busy) return;
    final exchange = _Exchange(text);
    setState(() {
      _busy = true;
      _exchanges.add(exchange);
      _question.clear();
    });
    try {
      exchange.answer = await widget.api.ask(_lang(context), widget.transcript.finalLines(), text);
    } on Object {
      exchange.failed = true;
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final lines = {for (final line in widget.transcript.finalLines()) line.number: line};

    return Scaffold(
      appBar: AppBar(title: Text(l10n.askAction)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final exchange in _exchanges) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: Card(
                      color: theme.colorScheme.primaryContainer,
                      child: Padding(padding: const EdgeInsets.all(12), child: Text(exchange.question)),
                    ),
                  ),
                  if (exchange.failed)
                    _AiError(message: l10n.aiError)
                  else if (exchange.answer == null)
                    Semantics(
                      liveRegion: true,
                      child: Padding(padding: const EdgeInsets.all(12), child: Text(l10n.askThinking)),
                    )
                  else
                    Semantics(
                      liveRegion: true,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(exchange.answer!.answer, style: theme.textTheme.bodyLarge),
                              if (exchange.answer!.citations.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(l10n.askSources, style: theme.textTheme.labelLarge),
                                for (final number in exchange.answer!.citations)
                                  if (lines[number] case final line?)
                                    CaptionTile(
                                      number: number,
                                      caption: Caption(
                                        id: 'cite-$number',
                                        speaker: line.speaker,
                                        text: line.text,
                                        isFinal: true,
                                        lang: '',
                                        ts: 0,
                                      ),
                                    ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _question,
                      decoration: InputDecoration(hintText: l10n.askHint, border: const OutlineInputBorder()),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _ask(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(tooltip: l10n.send, onPressed: _busy ? null : _ask, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiError extends StatelessWidget {
  const _AiError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
