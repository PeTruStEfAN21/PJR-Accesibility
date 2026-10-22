import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'join_link.dart';
import 'protocol.dart';

enum ConnectionStatus { connecting, connected, reconnecting, closed }

typedef ChannelFactory = WebSocketChannel Function(Uri uri);

/// Keeps one device connected to a meeting, reconnecting with backoff when the
/// network drops. Stops for good when the server says the session is unknown.
class SessionConnection extends ChangeNotifier {
  SessionConnection(this.link, this.role, {ChannelFactory? channelFactory})
      : _channelFactory = channelFactory ?? WebSocketChannel.connect;

  final JoinLink link;
  final String role;
  final ChannelFactory _channelFactory;

  final _events = StreamController<ServerEvent>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _retryTimer;
  int _attempt = 0;
  bool _disposed = false;

  ConnectionStatus status = ConnectionStatus.connecting;
  Map<String, int> peers = const {};

  Stream<ServerEvent> get events => _events.stream;

  int peerCount(String role) => peers[role] ?? 0;

  void connect() {
    if (_disposed) return;
    _channel = _channelFactory(link.socketUri(role));
    _subscription = _channel!.stream.listen(
      _onData,
      onDone: _onDone,
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void send(Map<String, Object> message) {
    if (status != ConnectionStatus.connected) return;
    _channel?.sink.add(jsonEncode(message));
  }

  void _onData(dynamic data) {
    final event = ServerEvent.fromJson(jsonDecode(data as String) as Map<String, dynamic>);
    if (event == null) return;
    switch (event) {
      case Joined(:final peers):
        _attempt = 0;
        this.peers = peers;
        _setStatus(ConnectionStatus.connected);
      case PeerChanged(:final role, :final connected):
        final updated = Map<String, int>.from(peers);
        updated[role] = ((updated[role] ?? 0) + (connected ? 1 : -1)).clamp(0, 1 << 30);
        peers = updated;
        notifyListeners();
      default:
        break;
    }
    _events.add(event);
  }

  void _onDone() {
    if (_disposed) return;
    final closeCode = _channel?.closeCode;
    // 4404 unknown session, 4400 bad role: retrying will not help.
    if (closeCode == 4404 || closeCode == 4400) {
      _setStatus(ConnectionStatus.closed);
      return;
    }
    _setStatus(ConnectionStatus.reconnecting);
    final delay = Duration(milliseconds: (500 * (1 << _attempt.clamp(0, 4))));
    _attempt++;
    _retryTimer = Timer(delay, connect);
  }

  void _setStatus(ConnectionStatus value) {
    if (status == value) return;
    status = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _events.close();
    super.dispose();
  }
}
