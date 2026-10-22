import 'tts_stub.dart' if (dart.library.js_interop) 'tts_web.dart' as platform;

/// Reads text out loud on the presenter's laptop (the browser's speech synthesis).
abstract class TtsService {
  /// Whether a voice for [localeId] (e.g. `ro-RO`) is installed.
  bool canSpeak(String localeId);

  /// Completes when the voice has finished: true if the whole text was spoken, false on error or no voice.
  Future<bool> speak(String text, String localeId);

  void cancel();
}

TtsService createTtsService() => platform.createTtsService();
