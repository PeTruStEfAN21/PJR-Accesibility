import 'package:flutter/material.dart';

import '../../core/transcript.dart';
import '../../l10n/app_localizations.dart';
import 'my_question.dart';

/// „Vreau să întreb”: alerts the speaker first, then lets the participant type the question, and shows
/// where the question is (sent, read out, not answered yet). [quickMessages] step aside while typing, so the
/// captions keep their room on a small phone with the keyboard open.
class AskPanel extends StatefulWidget {
  const AskPanel({
    super.key,
    required this.question,
    required this.onHand,
    required this.onSend,
    this.quickMessages = const SizedBox.shrink(),
  });

  final MyQuestion question;
  final VoidCallback onHand;
  final ValueChanged<String> onSend;
  final Widget quickMessages;

  @override
  State<AskPanel> createState() => _AskPanelState();
}

class _AskPanelState extends State<AskPanel> {
  final _text = TextEditingController();
  bool _composing = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _start() {
    widget.onHand();
    setState(() => _composing = true);
  }

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _text.clear();
    setState(() => _composing = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.question,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.question.state case final state? when state != MyQuestionState.answered)
            _QuestionStatus(state: state, onRetry: widget.question.retry),
          if (_composing)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    autofocus: true,
                    maxLength: 500,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    decoration: InputDecoration(hintText: l10n.myQuestionHint),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(tooltip: l10n.myQuestionSend, icon: const Icon(Icons.send), onPressed: _send),
              ],
            )
          else
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
              onPressed: _start,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.front_hand),
                  const SizedBox(width: 8),
                  Flexible(child: Text(l10n.myQuestionButton)),
                ],
              ),
            ),
          if (!_composing) ...[const SizedBox(height: 8), widget.quickMessages],
        ],
      ),
    );
  }
}

class _QuestionStatus extends StatelessWidget {
  const _QuestionStatus({required this.state, required this.onRetry});

  final MyQuestionState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (icon, text) = switch (state) {
      MyQuestionState.sent => (Icons.schedule_send, l10n.myQuestionSent),
      MyQuestionState.read => (Icons.record_voice_over, l10n.myQuestionRead),
      MyQuestionState.notFound => (Icons.search_off, l10n.myQuestionNotFound),
      MyQuestionState.answered => (Icons.check_circle, l10n.answeredTitle),
    };
    final canRetry = state == MyQuestionState.sent || state == MyQuestionState.notFound;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Icon(icon),
            Text(text, style: Theme.of(context).textTheme.bodyLarge),
            if (canRetry)
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: onRetry,
                child: Text(l10n.myQuestionRetry),
              ),
          ],
        ),
      ),
    );
  }
}

/// „Ți s-a răspuns”: the question, the short answer and the lines it comes from. Stays until closed.
class AnsweredCard extends StatelessWidget {
  const AnsweredCard({super.key, required this.question, required this.transcript});

  final MyQuestion question;
  final Transcript transcript;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final result = question.result!;
    final cited = {for (final line in transcript.finalLines()) line.number: line};
    return Semantics(
      container: true,
      liveRegion: true,
      child: Card(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        color: theme.colorScheme.secondaryContainer,
        // The parent decides how tall the card may be; longer answers scroll inside it.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: theme.colorScheme.onSecondaryContainer),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.answeredTitle,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  // Always in sight, even when a long answer scrolls inside the card.
                  IconButton(tooltip: l10n.close, icon: const Icon(Icons.close), onPressed: question.dismiss),
                ],
              ),
              const SizedBox(height: 4),
              Text(l10n.answeredQuestion(question.text ?? ''), style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(result.answer, style: theme.textTheme.titleLarge),
              for (final id in result.lineIds)
                if (cited[id] case final line?)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('#${line.number} ${line.text}', style: theme.textTheme.bodyMedium),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
