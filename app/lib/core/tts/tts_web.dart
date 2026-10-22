import 'dart:async';
import 'dart:js_interop';

import 'tts_service.dart';

@JS('speechSynthesis')
external _SpeechSynthesis get _synthesis;

extension type _SpeechSynthesis._(JSObject _) implements JSObject {
  external JSArray<_Voice> getVoices();
  external void speak(_Utterance utterance);
  external void cancel();
}

extension type _Voice._(JSObject _) implements JSObject {
  external String get lang;
}

@JS('SpeechSynthesisUtterance')
extension type _Utterance._(JSObject _) implements JSObject {
  external factory _Utterance(String text);
  external set lang(String value);
  external set voice(_Voice value);
  external set onend(JSFunction handler);
  external set onerror(JSFunction handler);
}

/// Chrome's speech synthesis. Uses the first installed voice whose language matches the spoken language.
class WebTtsService implements TtsService {
  _Voice? _voiceFor(String localeId) {
    final language = localeId.split('-').first.toLowerCase();
    for (final voice in _synthesis.getVoices().toDart) {
      if (voice.lang.toLowerCase().startsWith(language)) return voice;
    }
    return null;
  }

  @override
  bool canSpeak(String localeId) => _voiceFor(localeId) != null;

  @override
  Future<bool> speak(String text, String localeId) {
    final voice = _voiceFor(localeId);
    if (voice == null) return Future.value(false);
    final done = Completer<bool>();
    final utterance = _Utterance(text)
      ..lang = localeId
      ..voice = voice
      ..onend = ((JSAny? _) {
        if (!done.isCompleted) done.complete(true);
      }).toJS
      ..onerror = ((JSAny? _) {
        if (!done.isCompleted) done.complete(false);
      }).toJS;
    _synthesis.speak(utterance);
    return done.future;
  }

  @override
  void cancel() => _synthesis.cancel();
}

TtsService createTtsService() => WebTtsService();
