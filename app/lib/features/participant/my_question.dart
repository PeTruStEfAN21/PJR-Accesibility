import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/server_api.dart';
import '../../core/transcript.dart';

typedef AnswerChecker = Future<AnswerCheck> Function(String question, List<TranscriptLine> lines);

enum MyQuestionState { sent, read, answered, notFound }

/// The participant's own question: sent, read out loud, then answered.
///
/// After the question is read (or the participant asks to look again), every new final line restarts a
/// short wait; when the speaker pauses, the lines said since the question go to the AI, one call at a time,
/// until it finds the answer or five minutes pass. A server error stops the search quietly: no answer
/// card is better than a wrong one.
class MyQuestion extends ChangeNotifier {
  MyQuestion({
    required this.transcript,
    required this.check,
    this.settle = const Duration(seconds: 3),
    this.giveUp = const Duration(minutes: 5),
  }) {
    _finalCount = transcript.finalLines().length;
    transcript.addListener(_onTranscript);
  }

  final Transcript transcript;
  final AnswerChecker check;
  final Duration settle;
  final Duration giveUp;

  String? _id;
  String? _text;
  MyQuestionState? _state;
  AnswerCheck? _result;
  int _fromLine = 0;
  int _finalCount = 0;
  bool _searching = false;
  bool _inFlight = false;
  int _generation = 0;
  Timer? _settleTimer;
  Timer? _giveUpTimer;

  String? get id => _id;
  String? get text => _text;
  MyQuestionState? get state => _state;
  AnswerCheck? get result => _result;

  void asked(String id, String text) {
    _reset();
    _id = id;
    _text = text;
    _state = MyQuestionState.sent;
    _fromLine = transcript.finalLines().length;
    notifyListeners();
  }

  void markRead(String id) {
    if (id != _id || _state != MyQuestionState.sent) return;
    _state = MyQuestionState.read;
    _startSearch(checkNow: false);
    notifyListeners();
  }

  /// Look again: right away over what was said since the question, then on new lines for five minutes.
  void retry() {
    if (_id == null || _state == MyQuestionState.answered) return;
    _state = MyQuestionState.read;
    _startSearch(checkNow: true);
    notifyListeners();
  }

  void dismiss() {
    _reset();
    notifyListeners();
  }

  void _reset() {
    _generation++;
    _settleTimer?.cancel();
    _giveUpTimer?.cancel();
    _id = _text = null;
    _state = null;
    _result = null;
    _searching = false;
    _inFlight = false;
  }

  void _startSearch({required bool checkNow}) {
    _searching = true;
    _giveUpTimer?.cancel();
    _giveUpTimer = Timer(giveUp, _onGiveUp);
    if (checkNow && !_inFlight) {
      _settleTimer?.cancel();
      _settleTimer = Timer(Duration.zero, _check);
    }
  }

  void _onGiveUp() {
    if (_state != MyQuestionState.read) return;
    _searching = false;
    _settleTimer?.cancel();
    _state = MyQuestionState.notFound;
    notifyListeners();
  }

  void _onTranscript() {
    final count = transcript.finalLines().length;
    if (count <= _finalCount) return;
    _finalCount = count;
    if (!_searching || _inFlight) return;
    _settleTimer?.cancel();
    _settleTimer = Timer(settle, _check);
  }

  Future<void> _check() async {
    final lines = transcript.finalLines().skip(_fromLine).toList();
    final question = _text;
    if (!_searching || _inFlight || lines.isEmpty || question == null) return;
    final generation = _generation;
    _inFlight = true;
    try {
      final result = await check(question, lines);
      if (generation != _generation) return;
      _inFlight = false;
      if (!result.answered || !_searching) return;
      _searching = false;
      _giveUpTimer?.cancel();
      _settleTimer?.cancel();
      _result = result;
      _state = MyQuestionState.answered;
      notifyListeners();
    } on Object {
      if (generation != _generation) return;
      _inFlight = false;
      _searching = false;
    }
  }

  @override
  void dispose() {
    _generation++;
    _settleTimer?.cancel();
    _giveUpTimer?.cancel();
    transcript.removeListener(_onTranscript);
    super.dispose();
  }
}
