import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Learning the speaker's voice: a text to read in a normal voice for [duration], with a progress bar.
/// [onRecorded] runs when the time is up; [message] tells the speaker how the last attempt went; [intro]
/// replaces the presenter's explanation (the clarity coach explains it for an online meeting).
class EnrollView extends StatefulWidget {
  const EnrollView({
    super.key,
    required this.onRecorded,
    this.message,
    this.intro,
    this.duration = const Duration(seconds: 20),
  });

  final Future<void> Function() onRecorded;
  final String? message;
  final String? intro;
  final Duration duration;

  @override
  State<EnrollView> createState() => _EnrollViewState();
}

class _EnrollViewState extends State<EnrollView> with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(vsync: this, duration: widget.duration)..addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  Future<void> _onStatus(AnimationStatus status) async {
    if (status != AnimationStatus.completed) return;
    await widget.onRecorded();
    if (mounted) setState(() => _recording = false);
  }

  void _start() {
    setState(() => _recording = true);
    _progress.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(l10n.enrollTitle, style: theme.textTheme.headlineSmall)),
          const SizedBox(height: 8),
          Text(widget.intro ?? l10n.enrollIntro, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(l10n.enrollText, style: theme.textTheme.titleLarge?.copyWith(height: 1.5)),
          ),
          const SizedBox(height: 16),
          if (widget.message case final message?)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(message, style: theme.textTheme.titleMedium),
              ),
            ),
          if (_recording) ...[
            Text(l10n.enrollListening, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _progress,
              builder: (_, _) => LinearProgressIndicator(value: _progress.value, minHeight: 12),
            ),
          ] else
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(220, 56)),
              onPressed: _start,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [const Icon(Icons.mic), const SizedBox(width: 8), Text(l10n.enrollStart)],
              ),
            ),
        ],
      ),
    );
  }
}
