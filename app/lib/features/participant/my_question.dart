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
/// until it finds the answer or five minutes pass. Without AI on the server (503) the search stops quietly:
/// no answer card is better than a wrong one. Other errors and slow answers only skip that check.
class MyQuestion extends ChangeNotifier {
  MyQuestion({
    required this.transcript,
    required this.check,
    this.settle = const Duration(seconds: 3),
    this.giveUp = const Duration(minutes: 5),
    this.checkTimeout = const Duration(seconds: 20),
  }) {
    _seenNumber = transcript.lastNumber;
    transcript.addListener(_onTranscript);
  }

  final Transcript transcript;
  final AnswerChecker check;
  final Duration settle;
  final Duration giveUp;
  final Duration checkTimeout;

  /// The server accepts at most this many lines; the most recent ones matter.
  static const maxLines = 200;

  String? _id;
  String? _text;
  MyQuestionState? _state;
  AnswerCheck? _result;
  /// Lines numbered above this became final after the question was asked.
  int _fromNumber = 0;
  int _seenNumber = 0;
  bool _searching = false;
  bool _inFlight = false;
  int _sentUpTo = 0;
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
    _fromNumber = transcript.lastNumber;
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
    // Forget a check that may hang: its answer, if it ever comes, is ignored.
    _generation++;
    _inFlight = false;
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
    // Only a line that just became final counts; edits and removals do not.
    final last = transcript.lastNumber;
    if (last <= _seenNumber) return;
    _seenNumber = last;
    if (!_searching || _inFlight) return;
    _settleTimer?.cancel();
    _settleTimer = Timer(settle, _check);
  }

  Future<void> _check() async {
    final all = [for (final line in transcript.finalLines()) if (line.number > _fromNumber) line];
    final lines = all.length > maxLines ? all.sublist(all.length - maxLines) : all;
    final question = _text;
    if (!_searching || _inFlight || lines.isEmpty || question == null) return;
    final generation = _generation;
    _inFlight = true;
    _sentUpTo = transcript.lastNumber;
    try {
      final result = await check(question, lines).timeout(checkTimeout);
      if (generation != _generation) return;
      _inFlight = false;
      if (!_searching) return;
      if (!result.answered) return _checkAgainIfMoreWasSaid();
      _searching = false;
      _giveUpTimer?.cancel();
      _settleTimer?.cancel();
      _result = result;
      _state = MyQuestionState.answered;
      notifyListeners();
    } on Object catch (error) {
      if (generation != _generation) return;
      _inFlight = false;
      if (error is ApiException && error.statusCode == 503) {
        _searching = false;
        return;
      }
      _checkAgainIfMoreWasSaid();
    }
  }

  /// Lines said while a check ran were not in it: look at them once the speaker pauses.
  void _checkAgainIfMoreWasSaid() {
    if (!_searching || transcript.lastNumber <= _sentUpTo) return;
    _settleTimer?.cancel();
    _settleTimer = Timer(settle, _check);
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
