import 'package:flutter/foundation.dart';

import 'protocol.dart';

/// One numbered line as sent to the AI endpoints (`lines` in the API).
class TranscriptLine {
  const TranscriptLine({required this.number, required this.speaker, required this.text});

  final int number;
  final Speaker speaker;
  final String text;

  Map<String, Object> toJson() => {'id': number, 'speaker': speaker.name, 'text': text};
}

/// Captions of the current meeting, in arrival order. Partial captions are
/// replaced in place by later updates with the same id.
class Transcript extends ChangeNotifier {
  final List<Caption> _captions = [];

  List<Caption> get captions => List.unmodifiable(_captions);

  bool get isEmpty => _captions.isEmpty;

  void upsert(Caption caption) {
    if (caption.text.trim().isEmpty) return;
    final index = _captions.indexWhere((c) => c.id == caption.id);
    if (index == -1) {
      _captions.add(caption);
    } else {
      _captions[index] = caption;
    }
    notifyListeners();
  }

  void remove(String id) {
    final before = _captions.length;
    _captions.removeWhere((c) => c.id == id);
    if (_captions.length != before) notifyListeners();
  }

  /// Number of each final caption, matching [finalLines].
  Map<String, int> finalNumbers() {
    final numbers = <String, int>{};
    for (final caption in _captions) {
      if (caption.isFinal) numbers[caption.id] = numbers.length + 1;
    }
    return numbers;
  }

  Caption? latest(Speaker speaker) {
    for (final caption in _captions.reversed) {
      if (caption.speaker == speaker) return caption;
    }
    return null;
  }

  /// Final captions numbered from 1. Citations from the AI ("[#3]") refer to these numbers.
  List<TranscriptLine> finalLines() {
    final lines = <TranscriptLine>[];
    for (final caption in _captions) {
      if (!caption.isFinal) continue;
      lines.add(TranscriptLine(number: lines.length + 1, speaker: caption.speaker, text: caption.text.trim()));
    }
    return lines;
  }

  void clear() {
    _captions.clear();
    notifyListeners();
  }
}
