import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/account/account_service.dart';
import '../../core/session_connection.dart';
import '../../l10n/app_localizations.dart';
import '../alerts/alert_controller.dart';
import '../alerts/alert_signals.dart';
import '../alerts/sound_alert.dart';
import 'alarm_logic.dart';
import 'position_source.dart';

/// Listens to colleagues' alarms on `/ws/alarms` and reports those within range,
/// each at most once. Reconnects with backoff (1, 2, 4… 30 s), always with the current token.
class AlarmFeed {
  AlarmFeed(
    this.server, {
    required this.account,
    required this.positions,
    required this.onAlarm,
    required this.onCancelled,
    ChannelFactory? channelFactory,
  }) : _channelFactory = channelFactory ?? WebSocketChannel.connect;

  static const maxDelay = Duration(seconds: 30);

  final Uri server;
  final AccountService account;
  final PositionSource positions;
  final void Function(Alarm alarm) onAlarm;
  final void Function(String id) onCancelled;
  final ChannelFactory _channelFactory;

  final _seen = <String>{};
  final _cancelled = <String>{};
  final _own = <String>{};
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _retryTimer;
  int _attempt = 0;
  bool _running = false;

  Uri get _socketUri => server.replace(scheme: server.scheme == 'https' ? 'wss' : 'ws', path: '/ws/alarms');

  void start() {
    if (_running && _channel != null) return;
    _running = true;
    _retryTimer?.cancel();
    _connect();
  }

  void stop() {
    _running = false;
    _retryTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _subscription = null;
    _channel = null;
  }

  /// An alarm this phone raised: never shown here.
  void markOwn(String id) {
    _own.add(id);
    _seen.add(id);
  }

  void _connect() {
    if (!_running) return;
    final token = account.accessToken;
    if (token == null) {
      // Signed out: stay idle until start() is called again.
      _running = false;
      return;
    }
    final channel = _channel = _channelFactory(_socketUri);
    _subscription = channel.stream.listen(
      _onData,
      onDone: () => _onDone(channel),
      onError: (_) {},
      cancelOnError: false,
    );
    channel.sink.add(jsonEncode({'type': 'auth', 'token': token}));
  }

  void _onData(dynamic data) {
    final Object? message;
    try {
      message = jsonDecode(data as String);
    } on Object {
      return;
    }
    if (message is! Map) return;
    switch (message['type']) {
      case 'auth_ok':
        _attempt = 0;
      case 'alarm':
        final alarm = Alarm.fromJson(message);
        if (alarm == null || !_seen.add(alarm.id)) return;
        _report(alarm);
      case 'alarm_cancelled':
        final id = message['id'];
        if (id is! String) return;
        _cancelled.add(id);
        onCancelled(id);
    }
  }

  Future<void> _report(Alarm alarm) async {
    final here = await positions.current(timeout: const Duration(seconds: 5)) ?? await positions.lastKnown();
    if (_running && !_cancelled.contains(alarm.id) && !_own.contains(alarm.id) && inRange(alarm, here)) onAlarm(alarm);
  }

  void _onDone(WebSocketChannel channel) {
    if (!_running || !identical(channel, _channel)) return;
    _channel = null;
    final delay = Duration(seconds: math.min(1 << _attempt.clamp(0, 5), maxDelay.inSeconds));
    _attempt++;
    _retryTimer = Timer(delay, _connect);
  }
}

/// Puts a colleague's alarm on screen and in the notifications, and takes it down when cancelled.
class AlarmPresenter {
  AlarmPresenter(this.alerts, this.signals, this.l10n);

  final AlertController alerts;
  final AlertSignals signals;
  final AppLocalizations Function() l10n;

  final _shown = <String, SoundAlert>{};

  void show(Alarm alarm) {
    final strings = l10n();
    final alert = toSoundAlert(strings, alarm);
    _shown[alarm.id] = alert;
    signals.notify(alert, alert.label!, strings.alertOpenApp);
    alerts.show(alert);
  }

  void cancelled(String id) {
    final alert = _shown.remove(id);
    if (alert == null || !identical(alerts.current, alert)) return;
    alerts.dismiss();
    signals.clear();
  }
}
