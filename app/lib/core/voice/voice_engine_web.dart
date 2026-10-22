import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'voice_engine.dart';
import 'voice_head.dart';

/// `window.echoVoice`, defined by `web/voice/echo_voice.js`.
@JS('echoVoice')
external _EchoVoice? get _echoVoice;

extension type _EchoVoice._(JSObject _) implements JSObject {
  external JSPromise<JSBoolean> start();
  external void stop();
  external JSFloat32Array recent(double seconds);
  external JSPromise<JSFloat32Array> embed(JSFloat32Array samples);
  external JSPromise<JSString> headJson();
  external JSPromise<JSAny?> play(JSFloat32Array samples);
}

class WebVoiceEngine implements VoiceEngine {
  @override
  Future<bool> start() async {
    final voice = _echoVoice;
    if (voice == null) return false;
    try {
      return (await voice.start().toDart).toDart;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> stop() async => _echoVoice?.stop();

  @override
  Float32List recent(Duration length) =>
      _echoVoice?.recent(length.inMilliseconds / 1000).toDart ?? Float32List(0);

  @override
  Future<Float32List> embed(Float32List samples) async => (await _echoVoice!.embed(samples.toJS).toDart).toDart;

  @override
  Future<void> play(Float32List samples) async => _echoVoice?.play(samples.toJS).toDart;

  @override
  Future<VoiceHead> loadHead() async {
    try {
      final text = (await _echoVoice!.headJson().toDart).toDart;
      return VoiceHead.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } on Object {
      return VoiceHead.fallback;
    }
  }
}

VoiceEngine createVoiceEngine() => WebVoiceEngine();
