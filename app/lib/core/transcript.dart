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
///
/// Each caption gets a fixed number the first time it is final (1, 2, ... in that order). Numbers are
/// never shifted or reused, so a citation ("[#3]") keeps pointing at the same line.
class Transcript extends ChangeNotifier {
  final List<Caption> _captions = [];
  final Map<String, int> _numbers = {};
  int _lastNumber = 0;

  List<Caption> get captions => List.unmodifiable(_captions);

  bool get isEmpty => _captions.isEmpty;

  /// The highest number given so far (0 before the first final caption); only grows until [clear].
  int get lastNumber => _lastNumber;

  void upsert(Caption caption) {
    if (caption.text.trim().isEmpty) return;
    final index = _captions.indexWhere((c) => c.id == caption.id);
    if (index == -1) {
      _captions.add(caption);
    } else {
      _captions[index] = caption;
    }
    if (caption.isFinal) _numbers.putIfAbsent(caption.id, () => ++_lastNumber);
    notifyListeners();
  }

  void remove(String id) {
    final before = _captions.length;
    _captions.removeWhere((c) => c.id == id);
    if (_captions.length != before) notifyListeners();
  }

  /// Number of each final caption, matching [finalLines].
  Map<String, int> finalNumbers() => {
        for (final caption in _captions)
          if (caption.isFinal) caption.id: _numbers[caption.id]!,
      };

  Caption? latest(Speaker speaker) {
    for (final caption in _captions.reversed) {
      if (caption.speaker == speaker) return caption;
    }
    return null;
  }

  /// Final captions in arrival order, with their fixed numbers. Citations from the AI ("[#3]") refer to these.
  List<TranscriptLine> finalLines() => [
        for (final caption in _captions)
          if (caption.isFinal)
            TranscriptLine(number: _numbers[caption.id]!, speaker: caption.speaker, text: caption.text.trim()),
      ];

  void clear() {
    _captions.clear();
    _numbers.clear();
    _lastNumber = 0;
    notifyListeners();
  }
}
