import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'caption_segmenter.dart';

export 'caption_segmenter.dart' show SpeechSegment;

enum SpeechState { idle, listening, unavailable }

/// Speech recognition as a stream of captions. The demo uses the platform
/// engine (iOS SFSpeechRecognizer, Chrome Web Speech); a local Whisper engine
/// can implement this same interface later.
abstract class SpeechService {
  Stream<SpeechSegment> get segments;
  ValueListenable<SpeechState> get state;

  /// [localeId] in BCP 47 form, e.g. `ro-RO` or `en-US`.
  Future<bool> start(String localeId);
  Future<void> stop();
  void dispose();
}

class PlatformSpeechService implements SpeechService {
  PlatformSpeechService({SpeechToText? engine}) : _engine = engine ?? SpeechToText();

  static const _pauseCommit = Duration(milliseconds: 1200);
  static const _restartDelay = Duration(milliseconds: 250);

  final SpeechToText _engine;
  final _segmenter = CaptionSegmenter();
  final _segments = StreamController<SpeechSegment>.broadcast();
  final _state = ValueNotifier(SpeechState.idle);

  bool _initialized = false;
  bool _wanted = false;
  String _localeId = 'ro-RO';
  Timer? _pauseTimer;
  Timer? _restartTimer;

  @override
  Stream<SpeechSegment> get segments => _segments.stream;

  @override
  ValueListenable<SpeechState> get state => _state;

  @override
  Future<bool> start(String localeId) async {
    _localeId = localeId;
    if (!_initialized) {
      _initialized = await _engine.initialize(onStatus: _onStatus, onError: _onError);
      if (!_initialized) {
        _state.value = SpeechState.unavailable;
        return false;
      }
    }
    _wanted = true;
    await _listen();
    return true;
  }

  @override
  Future<void> stop() async {
    _wanted = false;
    _restartTimer?.cancel();
    _pauseTimer?.cancel();
    await _engine.stop();
    _emit(_segmenter.endSession());
    _state.value = SpeechState.idle;
  }

  Future<void> _listen() async {
    if (!_wanted || _engine.isListening) return;
    _state.value = SpeechState.listening;
    await _engine.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        localeId: _localeId,
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        autoPunctuation: true,
        // iOS stops recognition after about a minute; we restart it when it ends.
        listenFor: const Duration(seconds: 55),
        pauseFor: const Duration(seconds: 4),
      ),
    );
  }

  void _onResult(SpeechRecognitionResult result) {
    _emit(_segmenter.onWords(result.recognizedWords));
    _pauseTimer?.cancel();
    if (result.finalResult) {
      _emit(_segmenter.endSession());
    } else {
      _pauseTimer = Timer(_pauseCommit, () => _emit(_segmenter.commit()));
    }
  }

  void _onStatus(String status) {
    if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) {
      _emit(_segmenter.endSession());
      _scheduleRestart();
    }
  }

  void _onError(SpeechRecognitionError error) {
    final permanent = error.errorMsg.contains('permission') || error.errorMsg.contains('not-allowed');
    if (permanent) {
      _wanted = false;
      _state.value = SpeechState.unavailable;
      return;
    }
    // Timeouts and "no match" are normal during silence: keep listening.
    _scheduleRestart();
  }

  void _scheduleRestart() {
    if (!_wanted) return;
    _restartTimer?.cancel();
    _restartTimer = Timer(_restartDelay, _listen);
  }

  void _emit(SpeechSegment? segment) {
    if (segment != null && !_segments.isClosed) _segments.add(segment);
  }

  @override
  void dispose() {
    _wanted = false;
    _pauseTimer?.cancel();
    _restartTimer?.cancel();
    _engine.cancel();
    _segments.close();
    _state.dispose();
  }
}
