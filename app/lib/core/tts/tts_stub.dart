import 'tts_service.dart';

/// Outside the browser there is no speech synthesis: the speaker reads the question.
class UnavailableTtsService implements TtsService {
  @override
  bool canSpeak(String localeId) => false;

  @override
  Future<bool> speak(String text, String localeId) async => false;

  @override
  void cancel() {}
}

TtsService createTtsService() => UnavailableTtsService();
