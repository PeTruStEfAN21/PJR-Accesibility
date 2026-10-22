import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pjr_accesibilitate/app.dart';
import 'package:pjr_accesibilitate/core/account/account_service.dart';
import 'package:pjr_accesibilitate/core/history/meeting_store.dart';
import 'package:pjr_accesibilitate/core/protocol.dart';
import 'package:pjr_accesibilitate/core/server_api.dart';
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

  int? _closeCode;

  void receive(Map<String, Object> message) => _incoming.add(jsonEncode(message));

  /// The server closes the socket with [code].
  void closeWith(int code) {
    _closeCode = code;
    _incoming.close();
  }

  @override
  Stream get stream => _incoming.stream;

  @override
  int? get closeCode => _closeCode;

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
  /// Off by default: most tests do not care about voices, and the presenter page then skips enrollment.
  bool available = false;
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

  final played = <int>[];

  @override
  Future<void> play(Float32List samples) async => played.add(samples.length);
}

class FakeSounds implements SoundDetector {
  final controller = StreamController<SoundAlert>.broadcast();

  /// What each learning sample returns, in order; null = nothing heard.
  final samples = <Float32List?>[];

  /// What start() answers (false = microphone refused).
  bool canStart = true;
  bool listening = false;
  int starts = 0;
  int stops = 0;

  @override
  bool get isAvailable => true;

  @override
  Stream<SoundAlert> get alerts => controller.stream;

  @override
  Future<bool> start() async {
    starts++;
    listening = canStart;
    return canStart;
  }

  @override
  Future<void> stop() async {
    stops++;
    listening = false;
  }

  @override
  Future<Float32List?> recordSample(Duration duration) async => samples.isEmpty ? null : samples.removeAt(0);

  @override
  void dispose() {}
}

class FakeAccountService extends AccountService {
  FakeAccountService({AccountUser? user}) : _user = user;

  AccountUser? _user;
  String expectedCode = '123456';
  final sentCodes = <String>[];
  bool deleted = false;

  @override
  AccountUser? get user => _user;

  @override
  String? get accessToken => _user == null ? null : 'token-${_user!.id}';

  void signInAs(String email) {
    _user = AccountUser(id: 'u-$email', email: email);
    notifyListeners();
  }

  @override
  Future<void> sendEmailCode(String email) async => sentCodes.add(email);

  @override
  Future<void> verifyEmailCode(String email, String code) async {
    if (code != expectedCode) throw StateError('wrong code');
    signInAs(email);
  }

  @override
  Future<void> signInWithGoogle() async => signInAs('google@example.com');

  @override
  Future<void> signOut() async {
    _user = null;
    notifyListeners();
  }

  @override
  Future<void> deleteAccount() async {
    deleted = true;
    await signOut();
  }
}

/// Saved meetings in memory, with the same idempotent line saving as the database.
class FakeMeetingStore implements MeetingStore {
  final meetings = <String, SavedMeeting>{};
  final lines = <String, List<SavedLine>>{};
  final summaries = <String, MeetingSummary>{};
  final finished = <String>{};
  int saveCalls = 0;

  /// Makes the next saves fail, like a dropped connection.
  bool failSaves = false;

  SavedMeeting add(String title, List<String> texts, {DateTime? startedAt}) {
    final id = 'm${meetings.length + 1}';
    final meeting = SavedMeeting(id: id, title: title, startedAt: startedAt ?? DateTime(2026, 10, 20, 14, 5));
    meetings[id] = meeting;
    lines[id] = [
      for (final (i, text) in texts.indexed)
        SavedLine(seq: i + 1, captionId: 'c${i + 1}', speaker: Speaker.coordinator, text: text, spokenAt: meeting.startedAt),
    ];
    return meeting;
  }

  @override
  Future<String> createMeeting({String? sessionCode, required String lang, String? title}) async {
    if (failSaves) throw StateError('offline');
    final id = 'm${meetings.length + 1}';
    meetings[id] = SavedMeeting(id: id, title: title, startedAt: DateTime(2026, 10, 22));
    lines[id] = [];
    return id;
  }

  @override
  Future<void> saveLines(String meetingId, List<SavedLine> batch) async {
    saveCalls++;
    if (failSaves) throw StateError('offline');
    final saved = lines[meetingId]!;
    for (final line in batch) {
      if (!saved.any((l) => l.captionId == line.captionId)) saved.add(line);
    }
  }

  @override
  Future<void> finishMeeting(String meetingId) async {
    finished.add(meetingId);
  }

  @override
  Future<List<SavedMeeting>> listMeetings() async =>
      meetings.values.toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  @override
  Future<List<MeetingMatch>> search(String query) async {
    final q = query.toLowerCase();
    return [
      for (final meeting in await listMeetings())
        for (final line in lines[meeting.id]!.where((l) => l.text.toLowerCase().contains(q)).take(1))
          MeetingMatch(meeting: meeting, seq: line.seq, snippet: line.text),
    ];
  }

  @override
  Future<List<SavedLine>> loadLines(String meetingId) async => List.of(lines[meetingId]!);

  @override
  Future<void> saveSummary(String meetingId, MeetingSummary summary, String lang) async {
    summaries[meetingId] = summary;
  }

  @override
  Future<MeetingSummary?> loadSummary(String meetingId) async => summaries[meetingId];

  @override
  Future<void> renameMeeting(String meetingId, String title) async {
    final old = meetings[meetingId]!;
    meetings[meetingId] = SavedMeeting(id: old.id, title: title, startedAt: old.startedAt, endedAt: old.endedAt);
  }

  @override
  Future<void> deleteMeeting(String meetingId) async {
    meetings.remove(meetingId);
    lines.remove(meetingId);
    summaries.remove(meetingId);
  }
}

class TestHarness {
  TestHarness._(this.settings, this.speech, this.sounds, this.channel, this.alerts, this.account, this.meetings);

  final AppSettings settings;
  final FakeSpeech speech;
  final tts = FakeTts();
  final voice = FakeVoiceEngine();
  final FakeSounds sounds;
  final FakeChannel channel;

  /// The colleague-alarm feed's own socket, opened while someone is signed in.
  final alarmChannel = FakeChannel();
  final AlertController alerts;
  final FakeAccountService? account;
  final FakeMeetingStore? meetings;

  /// HTTP calls to the server (AI endpoints); set before [app] to answer them.
  http.Client? httpClient;

  /// [accounts] turns on sign-in and saved meetings, as when Supabase is configured.
  static Future<TestHarness> create({
    Map<String, Object> prefs = const {'uiLanguage': 'ro'},
    bool accounts = false,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    return TestHarness._(
      AppSettings(await SharedPreferences.getInstance()),
      FakeSpeech(),
      FakeSounds(),
      FakeChannel(),
      AlertController(haptic: (_) {}),
      accounts ? FakeAccountService() : null,
      accounts ? FakeMeetingStore() : null,
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
          channelFactory: (uri) => (uri.path == '/ws/alarms' ? alarmChannel : channel)..uri = uri,
          account: account,
          meetings: meetings,
        ),
      );
}
