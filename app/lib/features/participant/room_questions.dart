import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/protocol.dart';
import '../../core/transcript.dart';

typedef QuestionFinder = Future<List<int>> Function(List<TranscriptLine> lines);

/// Marks the questions asked from the room. Final room lines go to the AI in batches of up to five, a
/// second after they arrive; without the AI (no key, no network, no answer in 20 s) a local rule decides.
class RoomQuestions extends ChangeNotifier {
  RoomQuestions({
    required this.transcript,
    required this.find,
    required this.lang,
    this.timeout = const Duration(seconds: 20),
  }) {
    transcript.addListener(_onTranscript);
  }

  static const _batchSize = 5;
  static const _batchDelay = Duration(seconds: 1);

  final Transcript transcript;
  final QuestionFinder find;

  /// Speech locale, e.g. `ro-RO`: picks the question words of the local rule.
  final String lang;
  final Duration timeout;

  final _questions = <String>{};
  final _seen = <String>{};
  final _pending = <Caption>[];
  Timer? _timer;
  bool _disposed = false;

  bool isQuestion(String captionId) => _questions.contains(captionId);

  void _onTranscript() {
    for (final caption in transcript.captions) {
      if (caption.speaker != Speaker.public || !caption.isFinal || !_seen.add(caption.id)) continue;
      _pending.add(caption);
    }
    if (_pending.isNotEmpty) _timer ??= Timer(_batchDelay, _flush);
  }

  void _flush() {
    _timer = null;
    final numbers = transcript.finalNumbers();
    while (_pending.isNotEmpty) {
      final batch = _pending.take(_batchSize).toList();
      _pending.removeRange(0, batch.length);
      _send([
        for (final caption in batch)
          if (numbers[caption.id] != null)
            (
              caption,
              TranscriptLine(number: numbers[caption.id]!, speaker: caption.speaker, text: caption.text.trim()),
            ),
      ]);
    }
  }

  Future<void> _send(List<(Caption, TranscriptLine)> batch) async {
    if (batch.isEmpty) return;
    Set<String> found;
    try {
      final ids = (await find([for (final (_, line) in batch) line]).timeout(timeout)).toSet();
      found = {
        for (final (caption, line) in batch)
          if (ids.contains(line.number)) caption.id,
      };
    } on Object {
      found = {
        for (final (caption, _) in batch)
          if (looksLikeQuestion(caption.text, lang)) caption.id,
      };
    }
    if (_disposed || found.isEmpty) return;
    _questions.addAll(found);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    transcript.removeListener(_onTranscript);
    super.dispose();
  }
}

const _roQuestionStarts = [
  'cine',
  'ce',
  'cand',
  'cum',
  'de ce',
  'unde',
  'care',
  'cat',
  'cate',
  'poti',
  'puteti',
  'se poate',
];
const _enQuestionStarts = [
  'who',
  'what',
  'when',
  'how',
  'why',
  'where',
  'which',
  'can',
  'could',
  'do',
  'does',
  'is',
  'are',
];

const _diacritics = {'ă': 'a', 'â': 'a', 'î': 'i', 'ș': 's', 'ş': 's', 'ț': 't', 'ţ': 't'};

/// The local rule used without the AI: ends with "?" or starts with a question word.
bool looksLikeQuestion(String text, String lang) {
  final trimmed = text.trim();
  if (trimmed.endsWith('?')) return true;
  final plain = trimmed.toLowerCase().split('').map((c) => _diacritics[c] ?? c).join();
  final words = plain.split(RegExp(r'[^a-z]+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return false;
  final starts = lang.startsWith('ro')
      ? _roQuestionStarts
      : lang.startsWith('en')
      ? _enQuestionStarts
      : [..._roQuestionStarts, ..._enQuestionStarts];
  return starts.any((start) {
    final parts = start.split(' ');
    return words.length >= parts.length && words.take(parts.length).join(' ') == start;
  });
}
