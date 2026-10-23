import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pjr_accesibilitate/app.dart';
import 'package:pjr_accesibilitate/core/join_link.dart';
import 'package:pjr_accesibilitate/core/account/account_service.dart';
import 'package:pjr_accesibilitate/core/history/meeting_store.dart';
import 'package:pjr_accesibilitate/core/org/activity_store.dart';
import 'package:pjr_accesibilitate/core/org/org_store.dart';
import 'package:pjr_accesibilitate/core/org/organizations.dart';
import 'package:pjr_accesibilitate/core/protocol.dart';
import 'package:pjr_accesibilitate/core/server_api.dart';
import 'package:pjr_accesibilitate/core/services.dart';
import 'package:pjr_accesibilitate/core/speech/speech_service.dart';
import 'package:pjr_accesibilitate/core/tts/tts_service.dart';
import 'package:pjr_accesibilitate/core/voice/voice_engine.dart';
import 'package:pjr_accesibilitate/core/voice/voice_head.dart';
import 'package:pjr_accesibilitate/features/alerts/alert_controller.dart';
import 'package:pjr_accesibilitate/features/alerts/alert_signals.dart';
import 'package:pjr_accesibilitate/features/alerts/location_sounds.dart';
import 'package:pjr_accesibilitate/features/alerts/sound_alert.dart';
import 'package:pjr_accesibilitate/features/coach/alert_window.dart';
import 'package:pjr_accesibilitate/features/coach/coach_audio.dart';
import 'package:pjr_accesibilitate/features/home/phone_shell.dart';
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

  /// The browser's one microphone, shared with the coach's capture: closed, it hears nothing.
  bool micOpen = true;

  /// When set, starting waits for it (a model still loading).
  Completer<void>? starting;

  @override
  Future<bool> start() async {
    await starting?.future;
    micOpen = available;
    return available;
  }

  @override
  Future<void> stop() async => micOpen = false;

  @override
  Float32List recent(Duration length) {
    if (!micOpen) return Float32List(0);
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

class FakeCoachAudio implements CoachAudio {
  bool available = true;
  bool started = false;

  /// The microphone it shares with the voice model (as in echo_voice.js).
  FakeVoiceEngine? sharedWith;
  final controller = StreamController<Float32List>.broadcast();

  /// YAMNet scores for every window; null = YAMNet cannot run.
  List<double>? scores;
  final windows = <int>[];

  @override
  Future<bool> start() async {
    if (available) sharedWith?.micOpen = true;
    return started = available;
  }

  @override
  Stream<Float32List> get chunks => controller.stream;

  @override
  Future<List<double>?> yamnetScores(Float32List window) async {
    windows.add(window.length);
    return scores;
  }

  @override
  void stop() {
    started = false;
    sharedWith?.micOpen = false;
  }
}

class FakeAlertWindow implements AlertWindow {
  @override
  bool supported = true;
  bool isOpen = false;
  double? textScale;
  void Function()? _onClosed;
  final shown = <(String, String, bool)>[];

  @override
  Future<bool> open({
    required String title,
    required String language,
    required double textScale,
    required void Function() onClosed,
  }) async {
    this.textScale = textScale;
    _onClosed = onClosed;
    return isOpen = supported;
  }

  @override
  void show(String text, String icon, {required bool alert}) => shown.add((text, icon, alert));

  @override
  void close() {
    if (!isOpen) return;
    isOpen = false;
    _onClosed?.call();
  }
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

  /// False = the detector model is missing on this device.
  bool available = true;

  @override
  bool get isAvailable => available;

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

/// Alert signals that only record what was asked of them.
class FakeAlertSignals implements AlertSignals {
  final vibrated = <Haptic>[];
  int clears = 0;

  @override
  Future<void> requestPermission() async {}

  @override
  void vibrate(Haptic haptic) => vibrated.add(haptic);

  @override
  void notify(SoundAlert alert, String title, String body) {}

  @override
  void clear() => clears++;
}

class FakeAccountService extends AccountService {
  FakeAccountService({AccountUser? user}) : _user = user;

  AccountUser? _user;
  String expectedCode = '123456';
  final sentCodes = <String>[];
  bool deleted = false;

  /// Makes deleteAccount fail with this error, as the database would.
  Object? deleteError;

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
    if (deleteError != null) throw deleteError!;
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

  /// The company each meeting was saved for (null: only the owner's).
  final orgOf = <String, String?>{};

  /// Companies the user has left meanwhile: saving for them fails, as in the database.
  final goneOrgs = <String>{};
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
  Future<String> createMeeting({String? sessionCode, required String lang, String? title, String? orgId}) async {
    if (failSaves) throw StateError('offline');
    if (goneOrgs.contains(orgId)) throw const CompanyGoneException();
    final id = 'm${meetings.length + 1}';
    orgOf[id] = orgId;
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
  TestHarness._(this.settings, this.speech, this.sounds, this.channel, this.alerts, this.account, this.meetings,
      this.locationSounds, this.orgStore, this.organizations, this.activity) {
    coachAudio.sharedWith = voice;
  }

  final AppSettings settings;
  final FakeSpeech speech;
  final tts = FakeTts();
  final voice = FakeVoiceEngine();
  final coachAudio = FakeCoachAudio();
  final alertWindow = FakeAlertWindow();
  final FakeSounds sounds;
  final signals = FakeAlertSignals();
  final FakeChannel channel;

  /// The colleague-alarm feed's latest socket, opened while someone is signed in
  /// (a new one each time the feed connects, e.g. after the server address changes).
  FakeChannel alarmChannel = FakeChannel();
  final AlertController alerts;
  final FakeAccountService? account;
  final FakeMeetingStore? meetings;
  final LocationSoundStore locationSounds;

  /// With [create]'s accounts: the companies of whoever is signed in.
  final FakeOrgStore? orgStore;
  final Organizations? organizations;

  /// With [create]'s accounts: the activity log and the company meetings.
  final FakeActivityStore? activity;

  /// HTTP calls to the server (AI endpoints); set before [app] to answer them.
  http.Client? httpClient;

  /// [accounts] turns on sign-in and saved meetings, as when Supabase is configured.
  static Future<TestHarness> create({
    Map<String, Object> prefs = const {'uiLanguage': 'ro'},
    bool accounts = false,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final shared = await SharedPreferences.getInstance();
    final account = accounts ? FakeAccountService() : null;
    final locationSounds = LocationSoundStore(shared);
    final orgStore = account != null ? FakeOrgStore(account) : null;
    return TestHarness._(
      AppSettings(shared),
      FakeSpeech(),
      FakeSounds(),
      FakeChannel(),
      AlertController(haptic: (_) {}),
      account,
      accounts ? FakeMeetingStore() : null,
      locationSounds,
      orgStore,
      orgStore != null
          ? Organizations(store: orgStore, account: account!, sounds: locationSounds, model: SoundModel.tflite)
          : null,
      accounts ? FakeActivityStore() : null,
    );
  }

  /// [link]: opened from a meeting's QR link, as a guest.
  Widget app({JoinLink? link}) => EchoApp(
        settings: settings,
        alerts: alerts,
        link: link,
        services: AppServices(
          speech: speech,
          sounds: sounds,
          tts: tts,
          voice: voice,
          coachAudio: coachAudio,
          alertWindow: alertWindow,
          alertSignals: signals,
          httpClient: httpClient,
          channelFactory: (uri) => (uri.path == '/ws/alarms' ? alarmChannel = FakeChannel() : channel)..uri = uri,
          account: account,
          meetings: meetings,
          locationSounds: locationSounds,
          organizations: organizations,
          activity: activity,
        ),
      );
}


/// Organizations in memory, seen by whoever [account] says is signed in.
/// Enforces the few rules the screens rely on (admins only, invited email only).
class FakeOrgStore implements OrgStore {
  FakeOrgStore(this.account);

  final FakeAccountService account;
  final orgNames = <String, String>{};
  final people = <String, Map<String, OrgMember>>{};
  final invites = <String, ({String orgId, String email, OrgRole role, String? department})>{};
  final needs = <String, MemberNeeds>{};
  final sounds = <String, List<(LocationSound, SoundModel)>>{};
  final alarms = <String, ({String orgId, String kind, DateTime startedAt, bool open})>{};
  final answers = <String, Map<String, AlarmAnswer>>{};

  /// Company codes that work, without dashes, to their company.
  final joinCodes = <String, String>{};

  /// Makes joinWithCode refuse, as after five wrong codes in an hour.
  bool tooManyAttempts = false;
  static const _codes = ['ABCD-EFGH', 'JKMN-PQRS', 'TUVW-XYZ2'];
  int _codesMade = 0;
  int _ids = 0;

  String get _me => account.user!.id;
  String _id(String prefix) => '$prefix${++_ids}';
  bool _isAdmin(String orgId) => people[orgId]?[_me]?.role == OrgRole.admin;
  void _requireAdmin(String orgId) {
    if (!_isAdmin(orgId)) throw StateError('admins only');
  }

  /// Puts [userId] in an organization directly (test setup).
  void addMember(
    String orgId,
    String userId, {
    OrgRole role = OrgRole.employee,
    String? email,
    MemberNeeds? needs,
    String? displayName,
    MemberExperience experience = MemberExperience.standard,
  }) {
    people.putIfAbsent(orgId, () => {})[userId] =
        OrgMember(userId: userId, role: role, email: email, displayName: displayName, experience: experience);
    if (needs != null) this.needs['$orgId/$userId'] = needs;
  }

  String addOrg(String name) {
    final id = _id('org');
    orgNames[id] = name;
    return id;
  }

  @override
  Future<List<OrgMembership>> myOrganizations() async => [
        for (final MapEntry(key: orgId, value: people) in people.entries)
          if (account.user != null && people.containsKey(_me))
            OrgMembership(orgId: orgId, orgName: orgNames[orgId]!, role: people[_me]!.role),
      ];

  @override
  Future<List<OrgInvite>> myInvites() async => [
        for (final MapEntry(key: id, value: i) in invites.entries)
          if (i.email == account.user?.email) OrgInvite(id: id, orgId: i.orgId, orgName: orgNames[i.orgId]!, role: i.role),
      ];

  @override
  Future<String> createOrganization(String name) async {
    final id = addOrg(name);
    addMember(id, _me, role: OrgRole.admin, email: account.user!.email);
    return id;
  }

  @override
  Future<String> acceptInvite(String inviteId) async {
    final invite = invites[inviteId];
    if (invite == null || invite.email != account.user?.email) throw StateError('invitation not found');
    invites.remove(inviteId);
    people.putIfAbsent(invite.orgId, () => {})[_me] =
        OrgMember(userId: _me, role: invite.role, email: invite.email, department: invite.department);
    return invite.orgId;
  }

  @override
  Future<void> leave(String orgId, String userId) => removeMember(orgId, userId);

  @override
  Future<MemberNeeds?> loadNeeds(String orgId, String userId) async => needs['$orgId/$userId'];

  @override
  Future<void> saveNeeds(String orgId, String userId, MemberNeeds value) async {
    if (userId != _me) throw StateError('only the employee writes needs');
    needs['$orgId/$userId'] = value;
  }

  @override
  Future<List<OrgMember>> members(String orgId) async {
    _requireAdmin(orgId);
    return [
      for (final m in people[orgId]!.values)
        OrgMember(
          userId: m.userId,
          role: m.role,
          email: m.email,
          displayName: m.displayName,
          department: m.department,
          needs: needs['$orgId/${m.userId}'],
          experience: m.experience,
        ),
    ];
  }

  static String _plain(String code) => code.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

  @override
  Future<String> newJoinCode(String orgId) async {
    _requireAdmin(orgId);
    joinCodes.removeWhere((_, org) => org == orgId);
    final code = _codes[_codesMade++ % _codes.length];
    joinCodes[_plain(code)] = orgId;
    return code;
  }

  @override
  Future<DateTime?> joinCodeInfo(String orgId) async {
    _requireAdmin(orgId);
    return joinCodes.containsValue(orgId) ? DateTime(2026, 10, 30, 12) : null;
  }

  @override
  Future<void> revokeJoinCode(String orgId) async {
    _requireAdmin(orgId);
    joinCodes.removeWhere((_, org) => org == orgId);
  }

  @override
  Future<String?> joinWithCode(String code, String name, MemberExperience experience) async {
    if (tooManyAttempts) throw const JoinCodeTooManyAttempts();
    final org = joinCodes[_plain(code)];
    if (org == null) return null;
    people[org]!.putIfAbsent(
      _me,
      () => OrgMember(
        userId: _me,
        role: OrgRole.employee,
        email: account.user!.email,
        displayName: name.trim(),
        experience: experience,
      ),
    );
    return org;
  }

  @override
  Future<void> invite(String orgId, String email, {OrgRole role = OrgRole.employee, String? department}) async {
    _requireAdmin(orgId);
    invites[_id('inv')] = (orgId: orgId, email: email.trim().toLowerCase(), role: role, department: department);
  }

  @override
  Future<List<PendingInvite>> pendingInvites(String orgId) async {
    _requireAdmin(orgId);
    return [
      for (final MapEntry(key: id, value: i) in invites.entries)
        if (i.orgId == orgId) PendingInvite(id: id, email: i.email, role: i.role, department: i.department),
    ];
  }

  @override
  Future<void> cancelInvite(String inviteId) async => invites.remove(inviteId);

  @override
  Future<void> setRole(String orgId, String userId, OrgRole role) async {
    _requireAdmin(orgId);
    final m = people[orgId]![userId]!;
    people[orgId]![userId] = OrgMember(userId: userId, role: role, email: m.email, department: m.department);
  }

  @override
  Future<void> removeMember(String orgId, String userId) async {
    if (userId != _me) _requireAdmin(orgId);
    final others = people[orgId]!.values.where((m) => m.userId != userId);
    if (people[orgId]![userId]?.role == OrgRole.admin &&
        others.isNotEmpty &&
        !others.any((m) => m.role == OrgRole.admin)) {
      throw const LastAdminException();
    }
    people[orgId]!.remove(userId);
    needs.remove('$orgId/$userId');
    // The last person leaving takes the company with them.
    if (people[orgId]!.isEmpty) people.remove(orgId);
  }

  @override
  Future<List<LocationSound>> sharedSounds(String orgId, SoundModel model) async => [
        for (final (sound, m) in sounds[orgId] ?? const <(LocationSound, SoundModel)>[])
          if (m == model) sound,
      ];

  @override
  Future<void> shareSound(String orgId, LocationSound sound, SoundModel model) async {
    _requireAdmin(orgId);
    final shared = LocationSound(id: 'org-${_id('s')}', label: sound.label, level: sound.level, print: sound.print);
    sounds.putIfAbsent(orgId, () => []).add((shared, model));
  }

  @override
  Future<String> reportAlarm(String orgId, SoundKind kind) async {
    for (final MapEntry(key: id, value: a) in alarms.entries) {
      if (a.orgId == orgId && a.open) return id;
    }
    final id = _id('alarm');
    alarms[id] = (orgId: orgId, kind: kind.name, startedAt: DateTime(2026, 10, 22, 15), open: true);
    return id;
  }

  @override
  Future<void> answerAlarm(String orgId, String eventId, String userId, AlarmAnswerStatus status) async {
    answers.putIfAbsent(eventId, () => {})[userId] = AlarmAnswer(userId: userId, status: status, at: DateTime(2026));
  }

  @override
  Future<List<AlarmEvent>> openAlarms(String orgId) async => [
        for (final MapEntry(key: id, value: a) in alarms.entries)
          if (a.orgId == orgId && a.open) AlarmEvent(id: id, kind: a.kind, startedAt: a.startedAt),
      ];

  @override
  Future<List<AlarmAnswer>> alarmAnswers(String eventId) async => [...?answers[eventId]?.values];

  @override
  Future<void> closeAlarm(String eventId) async {
    final a = alarms[eventId]!;
    alarms[eventId] = (orgId: a.orgId, kind: a.kind, startedAt: a.startedAt, open: false);
  }
}

/// The activity log and company meetings in memory. [opened] lists the company
/// meetings read, in order: the database logs each reading in the employee's history.
class FakeActivityStore implements ActivityStore {
  final mine = <ActivityEntry>[];
  final company = <String, List<ActivityEntry>>{};
  final meetings = <String, List<CompanyMeeting>>{};
  final contents = <String, CompanyMeetingContent>{};
  final opened = <String>[];
  final pageRequests = <int?>[];

  /// Rows sent as events this app version does not know: counted in the page, not shown.
  final unknownIds = <int>{};

  ActivityPage _page(List<ActivityEntry> rows, int? beforeId, int maxRows) {
    final page = (List.of(rows)..sort((a, b) => b.id.compareTo(a.id)))
        .where((e) => beforeId == null || e.id < beforeId)
        .take(maxRows)
        .toList();
    return ActivityPage(
      entries: [for (final e in page) if (!unknownIds.contains(e.id)) e],
      rawCount: page.length,
      lastId: page.isEmpty ? null : page.last.id,
    );
  }

  @override
  Future<ActivityPage> myActivity({int? beforeId, int maxRows = 50}) async {
    pageRequests.add(beforeId);
    return _page(mine, beforeId, maxRows);
  }

  @override
  Future<ActivityPage> companyActivity(String orgId, {int? beforeId, int maxRows = 50}) async =>
      _page(company[orgId] ?? const [], beforeId, maxRows);

  @override
  Future<List<CompanyMeeting>> companyMeetings(String orgId) async => [...?meetings[orgId]];

  @override
  Future<CompanyMeetingContent> companyMeeting(String meetingId) async {
    final content = contents[meetingId];
    if (content == null) throw StateError('not a meeting of your company');
    opened.add(meetingId);
    return content;
  }
}

/// An entry of the phone's floating bar.
Finder inBar(String label) => find.descendant(of: find.byKey(PhoneShell.barKey), matching: find.text(label));

/// Opens one of the phone's main screens from the floating bar.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(inBar(label));
  await tester.pumpAndSettle();
}

/// Starts presenting the phone's way: Meeting in the bar, then Prezint, then Pornește meetingul.
Future<void> startPresenting(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await openTab(tester, 'Meeting');
  await tester.tap(find.text('Prezint'));
  await tester.pumpAndSettle();
  final start = find.text('Pornește meetingul');
  await tester.scrollUntilVisible(start, 200, scrollable: find.byType(Scrollable).last);
  await Scrollable.ensureVisible(tester.element(start), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(start);
  await tester.pumpAndSettle();
}
