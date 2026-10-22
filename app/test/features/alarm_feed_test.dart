import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pjr_accesibilitate/features/alerts/alert_controller.dart';
import 'package:pjr_accesibilitate/features/alerts/alert_signals.dart';
import 'package:pjr_accesibilitate/features/alerts/sound_alert.dart';
import 'package:pjr_accesibilitate/features/emergency/alarm_api.dart';
import 'package:pjr_accesibilitate/features/emergency/alarm_feed.dart';
import 'package:pjr_accesibilitate/features/emergency/alarm_logic.dart';
import 'package:pjr_accesibilitate/features/emergency/position_source.dart';
import 'package:pjr_accesibilitate/l10n/app_localizations_ro.dart';

import '../fakes.dart';

class FakePositions implements PositionSource {
  Position? now;
  Position? last;

  /// When set, [current] waits for it, like a slow GPS fix.
  Completer<Position?>? slow;

  @override
  Future<Position?> current({Duration timeout = const Duration(seconds: 5)}) async => slow?.future ?? now;

  @override
  Future<Position?> lastKnown() async => last;
}

/// An account whose token the test changes at will.
class TokenAccount extends FakeAccountService {
  String? token = 't1';

  @override
  String? get accessToken => token;
}

class RecordingSignals implements AlertSignals {
  final notified = <(SoundAlert, String, String)>[];
  int clears = 0;

  @override
  Future<void> requestPermission() async {}

  @override
  void vibrate(Haptic haptic) {}

  @override
  void notify(SoundAlert alert, String title, String body) => notified.add((alert, title, body));

  @override
  void clear() => clears++;
}

const here = Position(lat: 44.0, lon: 26.0, accuracyM: 10);

Map<String, Object> alarmMessage(String id, {double lat = 44.0}) =>
    {'type': 'alarm', 'id': id, 'kind': 'fire', 'at': 1792800000.0, 'lat': lat, 'lon': 26.0, 'accuracy_m': 10.0};

void main() {
  group('AlarmFeed', () {
    late TokenAccount account;
    late FakePositions positions;
    late List<FakeChannel> channels;
    late List<Alarm> shown;
    late List<String> cancelled;
    late AlarmFeed feed;

    setUp(() {
      account = TokenAccount();
      positions = FakePositions()..now = here;
      channels = [];
      shown = [];
      cancelled = [];
      feed = AlarmFeed(
        Uri.parse('https://echo.example/'),
        account: account,
        positions: positions,
        onAlarm: shown.add,
        onCancelled: cancelled.add,
        channelFactory: (uri) {
          final channel = FakeChannel()..uri = uri;
          channels.add(channel);
          return channel;
        },
      );
    });

    tearDown(() => feed.stop());

    test('sends the token first', () async {
      feed.start();
      await pumpEventQueue();
      expect(channels.single.uri.toString(), 'wss://echo.example/ws/alarms');
      expect(channels.single.sink.sent.first, {'type': 'auth', 'token': 't1'});
    });

    test('an alarm in range is shown once', () async {
      feed.start();
      channels.single.receive({'type': 'auth_ok'});
      channels.single.receive(alarmMessage('a1'));
      channels.single.receive(alarmMessage('a1'));
      await pumpEventQueue();
      expect(shown.map((a) => a.id), ['a1']);
    });

    test('an alarm out of range is ignored', () async {
      feed.start();
      channels.single.receive(alarmMessage('a1', lat: 44.0 + 2000 / 111195));
      await pumpEventQueue();
      expect(shown, isEmpty);
    });

    test('no position at all still shows the alarm', () async {
      positions.now = null;
      positions.last = null;
      feed.start();
      channels.single.receive(alarmMessage('a1'));
      await pumpEventQueue();
      expect(shown.map((a) => a.id), ['a1']);
    });

    test('falls back to the last known position', () async {
      positions.now = null;
      positions.last = const Position(lat: 45.0, lon: 26.0, accuracyM: 10);
      feed.start();
      channels.single.receive(alarmMessage('a1'));
      await pumpEventQueue();
      expect(shown, isEmpty);
    });

    test('own alarms are ignored', () async {
      feed.start();
      feed.markOwn('a1');
      channels.single.receive(alarmMessage('a1'));
      await pumpEventQueue();
      expect(shown, isEmpty);
    });

    test('cancellations and unknown messages', () async {
      feed.start();
      channels.single.receive({'type': 'mystery'});
      channels.single.receive({'type': 'alarm', 'id': 'bad'});
      channels.single.receive({'type': 'alarm_cancelled', 'id': 'a1'});
      await pumpEventQueue();
      expect(shown, isEmpty);
      expect(cancelled, ['a1']);
    });

    test('an alarm cancelled while locating is not shown', () async {
      positions.slow = Completer();
      feed.start();
      channels.single.receive(alarmMessage('a1'));
      channels.single.receive({'type': 'alarm_cancelled', 'id': 'a1'});
      await pumpEventQueue();
      positions.slow!.complete(here);
      await pumpEventQueue();
      expect(shown, isEmpty);
    });

    test('without a token it does not connect', () async {
      account.token = null;
      feed.start();
      await pumpEventQueue();
      expect(channels, isEmpty);
    });

    test('reconnects with the new token after 4401', () {
      fakeAsync((async) {
        feed.start();
        async.flushMicrotasks();
        account.token = 't2';
        channels.single.closeWith(4401);
        async.flushMicrotasks();
        expect(channels, hasLength(1));
        async.elapse(const Duration(seconds: 1));
        expect(channels, hasLength(2));
        expect(channels.last.sink.sent.first, {'type': 'auth', 'token': 't2'});
      });
    });

    test('backs off 1, 2, 4 seconds', () {
      fakeAsync((async) {
        feed.start();
        channels.last.closeWith(1006);
        async.elapse(const Duration(seconds: 1));
        expect(channels, hasLength(2));
        channels.last.closeWith(1006);
        async.elapse(const Duration(milliseconds: 1900));
        expect(channels, hasLength(2));
        async.elapse(const Duration(milliseconds: 100));
        expect(channels, hasLength(3));
        channels.last.closeWith(1006);
        async.elapse(const Duration(milliseconds: 3900));
        expect(channels, hasLength(3));
        async.elapse(const Duration(milliseconds: 100));
        expect(channels, hasLength(4));
      });
    });

    test('stop ends reconnecting', () {
      fakeAsync((async) {
        feed.start();
        feed.stop();
        channels.last.closeWith(1006);
        async.elapse(const Duration(seconds: 60));
        expect(channels, hasLength(1));
      });
    });
  });

  group('AlarmPresenter', () {
    late AlertController alerts;
    late RecordingSignals signals;
    late AlarmPresenter presenter;
    final alarm = Alarm.fromJson(alarmMessage('a1'))!;

    setUp(() {
      alerts = AlertController(haptic: (_) {});
      signals = RecordingSignals();
      presenter = AlarmPresenter(alerts, signals, () => AppLocalizationsRo());
    });

    tearDown(() => alerts.dispose());

    test('show notifies and puts the colleague alert on screen', () {
      presenter.show(alarm);
      final label = AppLocalizationsRo().alarmFromColleague(AppLocalizationsRo().alarmFire);
      expect(alerts.current?.label, label);
      expect(signals.notified.single.$2, label);
      expect(signals.notified.single.$3, AppLocalizationsRo().alertOpenApp);
    });

    test('cancelled closes the alert it showed', () {
      presenter.show(alarm);
      presenter.cancelled('a1');
      expect(alerts.current, isNull);
      expect(signals.clears, 1);
    });

    test('cancelled leaves another alert alone', () {
      presenter.show(alarm);
      final other = SoundAlert(SoundKind.siren, at: DateTime(2026, 10, 23), level: AlertLevel.critical);
      alerts.show(other);
      presenter.cancelled('a1');
      expect(alerts.current, same(other));
      expect(signals.clears, 0);
    });
  });

  group('AlarmApi', () {
    late List<http.Request> requests;

    AlarmApi apiAnswering(int status, String body, {Map<String, String> headers = const {}}) {
      requests = [];
      return AlarmApi(
        Uri.parse('https://echo.example/'),
        token: () => 't1',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(body, status, headers: headers);
        }),
      );
    }

    test('201 gives the raised alarm, with the bearer token', () async {
      final api = apiAnswering(201, jsonEncode({'id': 'a1', 'at': 1792800000.5}));
      final raised = await api.raise(AlarmKind.fire, here);
      expect(raised.id, 'a1');
      expect(raised.at, DateTime.fromMillisecondsSinceEpoch(1792800000500));
      final request = requests.single;
      expect(request.url.toString(), 'https://echo.example/api/alarms');
      expect(request.headers['Authorization'], 'Bearer t1');
      expect(jsonDecode(request.body), {'kind': 'fire', 'lat': 44.0, 'lon': 26.0, 'accuracy_m': 10.0});
    });

    test('cancel posts to the alarm', () async {
      final api = apiAnswering(200, jsonEncode({'id': 'a1'}));
      await api.cancel('a1');
      expect(requests.single.url.path, '/api/alarms/a1/cancel');
      expect(requests.single.headers['Authorization'], 'Bearer t1');
    });

    Future<AlarmError> errorFor(int status, {Map<String, String> headers = const {}}) async {
      final api = apiAnswering(status, '{}', headers: headers);
      try {
        await api.raise(AlarmKind.fire, here);
      } on AlarmError catch (e) {
        return e;
      }
      fail('no error');
    }

    test('401, 503, 429 and others map to problems', () async {
      expect((await errorFor(401)).problem, AlarmProblem.signedOut);
      expect((await errorFor(503)).problem, AlarmProblem.notConfigured);
      final tooMany = await errorFor(429, headers: {'retry-after': '42'});
      expect(tooMany.problem, AlarmProblem.tooMany);
      expect(tooMany.retryAfterSeconds, 42);
      expect((await errorFor(500)).problem, AlarmProblem.failed);
    });

    test('a network error is offline', () async {
      final api = AlarmApi(
        Uri.parse('https://echo.example/'),
        token: () => 't1',
        client: MockClient((_) async => throw http.ClientException('down')),
      );
      expect(
        () => api.raise(AlarmKind.fire, here),
        throwsA(isA<AlarmError>().having((e) => e.problem, 'problem', AlarmProblem.offline)),
      );
    });
  });
}
