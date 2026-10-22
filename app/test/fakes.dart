import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pjr_accesibilitate/app.dart';
import 'package:pjr_accesibilitate/core/account/account_service.dart';
import 'package:pjr_accesibilitate/core/history/meeting_store.dart';
import 'package:pjr_accesibilitate/core/protocol.dart';
import 'package:pjr_accesibilitate/core/server_api.dart';
import 'package:pjr_accesibilitate/core/services.dart';
import 'package:pjr_accesibilitate/core/speech/speech_service.dart';
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
  final FakeSounds sounds;
  final FakeChannel channel;
  final AlertController alerts;
  final FakeAccountService? account;
  final FakeMeetingStore? meetings;

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
          channelFactory: (uri) => channel..uri = uri,
          account: account,
          meetings: meetings,
        ),
      );
}
