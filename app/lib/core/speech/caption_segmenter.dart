import '../ids.dart';

class SpeechSegment {
  const SpeechSegment({required this.id, required this.text, required this.isFinal});
  final String id;
  final String text;
  final bool isFinal;
}

/// Splits the recogniser's ever-growing text into separate captions.
///
/// Chrome keeps one listen session open and reports the whole session text on
/// every update, never marking it final; iOS ends a session after each pause.
/// Both are handled the same way: the text already turned into captions is
/// remembered and only the rest becomes the current caption. A caption is
/// closed on a pause ([commit]), at the end of a session, or after [maxWords].
class CaptionSegmenter {
  CaptionSegmenter({this.maxWords = 30, String Function()? idGenerator}) : _newId = idGenerator ?? newId;

  final int maxWords;
  final String Function() _newId;

  String _committed = '';
  String _lastWords = '';
  String? _currentId;
  String _currentText = '';

  SpeechSegment? onWords(String words) {
    _lastWords = words;
    final rest = (words.length > _committed.length ? words.substring(_committed.length) : '').trim();
    if (rest.isEmpty) return null;
    _currentId ??= _newId();
    _currentText = rest;
    if (rest.split(RegExp(r'\s+')).length >= maxWords) return commit();
    return SpeechSegment(id: _currentId!, text: rest, isFinal: false);
  }

  /// Closes the current caption, if there is one.
  SpeechSegment? commit() {
    final id = _currentId;
    if (id == null) return null;
    final segment = SpeechSegment(id: id, text: _currentText, isFinal: true);
    _committed = _lastWords;
    _currentId = null;
    _currentText = '';
    return segment;
  }

  /// The recogniser started a new session: its text starts again from empty.
  SpeechSegment? endSession() {
    final segment = commit();
    _committed = '';
    _lastWords = '';
    return segment;
  }
}
