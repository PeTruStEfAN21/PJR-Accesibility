import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pjr_accesibilitate/app.dart';
import 'package:pjr_accesibilitate/core/services.dart';
import 'package:pjr_accesibilitate/core/speech/speech_service.dart';
import 'package:pjr_accesibilitate/core/tts/tts_service.dart';
import 'package:pjr_accesibilitate/core/voice/voice_engine.dart';
import 'package:pjr_accesibilitate/core/voice/voice_head.dart';
import 'package:pjr_accesibilitate/features/alerts/alert_controller.dart';
import 'package:pjr_accesibilitate/features/alerts/sound_alert.dart';
import 'package:pjr_accesibilitate/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class FakeSink implements WebSocketSink {
  final sent = <Map<String, dynamic>>[];

  @override
  void add(dynamic data) => sent.add(jsonDecode(data as String) as Map<String, dynamic>);

  @override
  Future close([int? closeCode, String? closeReason]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A WebSocket the test drives by hand: [receive] plays a server message.
class FakeChannel implements WebSocketChannel {
  final _incoming = StreamController<dynamic>();
  @override
  final FakeSink sink = FakeSink();
  Uri? uri;

  void receive(Map<String, Object> message) => _incoming.add(jsonEncode(message));

  @override
  Stream get stream => _incoming.stream;

  @override
  int? get closeCode => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSpeech implements SpeechService {
  final _segments = StreamController<SpeechSegment>.broadcast();
  final _state = ValueNotifier(SpeechState.idle);
  bool available = true;
  String? localeId;

  void say(String id, String text, {bool isFinal = true}) =>
      _segments.add(SpeechSegment(id: id, text: text, isFinal: isFinal));

  @override
  Stream<SpeechSegment> get segments => _segments.stream;

  @override
  ValueListenable<SpeechState> get state => _state;

  @override
  Future<bool> start(String localeId) async {
    this.localeId = localeId;
    if (available) _state.value = SpeechState.listening;
    return available;
  }

  @override
  Future<void> stop() async => _state.value = SpeechState.idle;

  @override
  void dispose() {}
}

/// Voice synthesis the test controls: [finish] ends a pending [speak] when [autoFinish] is off.
class FakeTts implements TtsService {
  bool available = true;
  bool autoFinish = true;
  final spoken = <String>[];
  Completer<bool>? _pending;

  void finish(bool ok) => _pending?.complete(ok);

  @override
  bool canSpeak(String localeId) => available;

  @override
  Future<bool> speak(String text, String localeId) {
    spoken.add(text);
    if (autoFinish) return Future.value(true);
    return (_pending = Completer<bool>()).future;
  }

  @override
  void cancel() {}
}

/// Microphone + speaker model the test controls: [audio] is what was heard most recently,
/// [vectorFor] decides the embedding of each clip.
class FakeVoiceEngine implements VoiceEngine {
  bool available = true;
  Float32List audio = Float32List(0);
  Float32List Function(Float32List samples) vectorFor = (_) => Float32List.fromList([1, 0, 0]);
  VoiceHead head = VoiceHead.fallback;
  final recentRequests = <Duration>[];
  final embedded = <int>[];

  @override
  Future<bool> start() async => available;

  @override
  Future<void> stop() async {}

  @override
  Float32List recent(Duration length) {
    recentRequests.add(length);
    final n = length.inMilliseconds * 16;
    return Float32List.sublistView(audio, max(0, audio.length - n));
  }

  @override
  Future<Float32List> embed(Float32List samples) async {
    embedded.add(samples.length);
    return vectorFor(samples);
  }

  @override
  Future<VoiceHead> loadHead() async => head;
}

class FakeSounds implements SoundDetector {
  final controller = StreamController<SoundAlert>.broadcast();

  @override
  bool get isAvailable => true;

  @override
  Stream<SoundAlert> get alerts => controller.stream;

  @override
  Future<bool> start() async => true;

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

class TestHarness {
  TestHarness._(this.settings, this.speech, this.sounds, this.channel, this.alerts);

  final AppSettings settings;
  final FakeSpeech speech;
  final tts = FakeTts();
  final voice = FakeVoiceEngine();
  final FakeSounds sounds;
  final FakeChannel channel;
  final AlertController alerts;

  /// HTTP calls to the server (AI endpoints); set before [app] to answer them.
  http.Client? httpClient;

  static Future<TestHarness> create({Map<String, Object> prefs = const {'uiLanguage': 'ro'}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    return TestHarness._(
      AppSettings(await SharedPreferences.getInstance()),
      FakeSpeech(),
      FakeSounds(),
      FakeChannel(),
      AlertController(haptic: (_) {}),
    );
  }

  Widget app() => EchoApp(
        settings: settings,
        alerts: alerts,
        services: AppServices(
          speech: speech,
          sounds: sounds,
          tts: tts,
          voice: voice,
          httpClient: httpClient,
          channelFactory: (uri) => channel..uri = uri,
        ),
      );
}
