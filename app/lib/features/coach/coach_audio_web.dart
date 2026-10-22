import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import '../alerts/yamnet_model.dart';
import 'coach_audio.dart';

/// `window.echoVoice`, defined by `web/voice/echo_voice.js`.
@JS('echoVoice')
external _EchoVoice? get _echoVoice;

extension type _EchoVoice._(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> startCapture();
  external void onChunk(JSFunction listener);
  external void offChunk(JSFunction listener);
  external void stop();
}

/// The microphone shared with the speaker model (`echo_voice.js`), and YAMNet through TensorFlow.js.
class WebCoachAudio implements CoachAudio {
  final _chunks = StreamController<Float32List>.broadcast();
  JSFunction? _listener;
  YamnetModel? _yamnet;
  bool _yamnetFailed = false;

  @override
  Future<bool> start() async {
    final voice = _echoVoice;
    if (voice == null) return false;
    try {
      if (!(await voice.startCapture().toDart).toDart) return false;
    } on Object {
      return false;
    }
    final listener = _listener ??= ((JSFloat32Array chunk) => _chunks.add(chunk.toDart)).toJS;
    voice.onChunk(listener);
    return true;
  }

  @override
  Stream<Float32List> get chunks => _chunks.stream;

  @override
  Future<List<double>?> yamnetScores(Float32List window) async {
    if (_yamnetFailed) return null;
    try {
      final yamnet = _yamnet ??= createYamnetModel();
      await yamnet.load();
      return (await yamnet.run(window)).scores;
    } on Object {
      // Without YAMNet the coach still works; only the noise alert is off.
      _yamnetFailed = true;
      return null;
    }
  }

  @override
  void stop() {
    final listener = _listener;
    if (listener != null) _echoVoice?.offChunk(listener);
    _echoVoice?.stop();
  }
}

CoachAudio createCoachAudio() => WebCoachAudio();
