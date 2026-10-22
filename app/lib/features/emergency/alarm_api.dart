import 'dart:convert';

import 'package:http/http.dart' as http;

import 'alarm_logic.dart';

enum AlarmProblem { signedOut, notConfigured, tooMany, offline, failed }

class AlarmError implements Exception {
  const AlarmError(this.problem, {this.retryAfterSeconds});
  final AlarmProblem problem;

  /// From the `Retry-After` header of a 429.
  final int? retryAfterSeconds;

  @override
  String toString() => 'AlarmError($problem)';
}

class RaisedAlarm {
  const RaisedAlarm({required this.id, required this.at});
  final String id;
  final DateTime at;
}

/// The alarm this phone sent last, and its kind.
class SentAlarm {
  const SentAlarm(this.alarm, this.kind);
  final RaisedAlarm alarm;
  final AlarmKind kind;
}

/// Keeps the alarm this phone sent beyond the emergency screen, so it can still be cancelled
/// after going back. Forgets it once it is no longer active on the server (15 min).
class SentAlarmMemory {
  SentAlarmMemory({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const activeFor = Duration(minutes: 15);

  final DateTime Function() _clock;
  SentAlarm? _sent;

  SentAlarm? get sent {
    final sent = _sent;
    if (sent != null && _clock().difference(sent.alarm.at) >= activeFor) _sent = null;
    return _sent;
  }

  set sent(SentAlarm? value) => _sent = value;
}

/// Raising and cancelling alarms; both need the signed-in user's token.
class AlarmApi {
  AlarmApi(this.server, {http.Client? client, required String? Function() token})
      : _client = client ?? http.Client(),
        _token = token;

  /// A dead network must not hold the confirmation dialog open for a minute or more.
  static const requestTimeout = Duration(seconds: 10);

  final Uri server;
  final http.Client _client;
  final String? Function() _token;

  Future<RaisedAlarm> raise(AlarmKind kind, Position at) async {
    final json = await _post('/api/alarms', {
      'kind': kind.wire,
      'lat': at.lat,
      'lon': at.lon,
      'accuracy_m': at.accuracyM,
    });
    final id = json['id'];
    final when = json['at'];
    if (id is! String || when is! num) throw const AlarmError(AlarmProblem.failed);
    return RaisedAlarm(id: id, at: DateTime.fromMillisecondsSinceEpoch((when * 1000).round()));
  }

  Future<void> cancel(String id) async {
    await _post('/api/alarms/${Uri.encodeComponent(id)}/cancel', {});
  }

  Future<Map> _post(String path, Map<String, Object> body) async {
    final token = _token();
    if (token == null) throw const AlarmError(AlarmProblem.signedOut);
    final http.Response response;
    try {
      response = await _client.post(
        server.resolve(path),
        headers: {'content-type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(body),
      ).timeout(requestTimeout);
    } on Object {
      throw const AlarmError(AlarmProblem.offline);
    }
    switch (response.statusCode) {
      case >= 200 && < 300:
        try {
          return jsonDecode(utf8.decode(response.bodyBytes)) as Map;
        } on Object {
          throw const AlarmError(AlarmProblem.failed);
        }
      case 401:
        throw const AlarmError(AlarmProblem.signedOut);
      case 503:
        throw const AlarmError(AlarmProblem.notConfigured);
      case 429:
        throw AlarmError(AlarmProblem.tooMany, retryAfterSeconds: int.tryParse(response.headers['retry-after'] ?? ''));
      default:
        throw const AlarmError(AlarmProblem.failed);
    }
  }
}
