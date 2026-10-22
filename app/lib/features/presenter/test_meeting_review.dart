import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/download/download.dart';
import '../../core/protocol.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/caption_tile.dart';
import 'test_meeting.dart';

/// After a test meeting: the team listens to each line, fixes who said it, and downloads the archive
/// for training (ml/voice/data/meetings).
class TestMeetingReview extends StatelessWidget {
  const TestMeetingReview({super.key, required this.recorder, required this.play, this.download = downloadBytes});

  final TestMeetingRecorder recorder;
  final Future<void> Function(Float32List samples) play;
  final void Function(Uint8List bytes, String fileName) download;

  void _download() {
    final stamp = DateFormat('yyyyMMdd-HHmm').format(clock.now());
    download(recorder.buildArchive(), 'echo-test-meeting-$stamp.zip');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.testReviewTitle)),
      body: ListenableBuilder(
        listenable: recorder,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.testReviewIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            for (final line in recorder.lines)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.text, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        l10n.testPredicted(
                          speakerLabel(l10n, line.predicted),
                          line.score == null ? '–' : line.score!.toStringAsFixed(2),
                        ),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                            onPressed: () => play(line.clip),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(l10n.testListen),
                          ),
                          SegmentedButton<Speaker>(
                            segments: [
                              for (final speaker in Speaker.values)
                                ButtonSegment(
                                  value: speaker,
                                  icon: Icon(speakerIcon(speaker)),
                                  label: Text(speakerLabel(l10n, speaker)),
                                ),
                            ],
                            selected: {line.label},
                            onSelectionChanged: (selected) => recorder.setLabel(line.id, selected.first),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
              onPressed: _download,
              icon: const Icon(Icons.download),
              label: Text(l10n.testDownload),
            ),
          ],
        ),
      ),
    );
  }
}
