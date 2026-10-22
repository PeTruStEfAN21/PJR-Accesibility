// Messages exchanged over the meeting WebSocket. Mirrors server/app/protocol.py.

enum Speaker { coordinator, public }

enum NotifyKind { question, repeat, slower, custom }

class Caption {
  const Caption({
    required this.id,
    required this.speaker,
    required this.text,
    required this.isFinal,
    required this.lang,
    required this.ts,
  });

  final String id;
  final Speaker speaker;
  final String text;
  final bool isFinal;
  final String lang;
  final int ts;

  Map<String, Object> toJson() => {
        'type': 'caption',
        'id': id,
        'speaker': speaker.name,
        'text': text,
        'final': isFinal,
        'lang': lang,
        'ts': ts,
      };

  static Caption fromJson(Map<String, dynamic> json) => Caption(
        id: json['id'] as String,
        speaker: Speaker.values.byName(json['speaker'] as String),
        text: json['text'] as String,
        isFinal: json['final'] as bool,
        lang: json['lang'] as String,
        ts: json['ts'] as int,
      );
}

class Notify {
  const Notify({required this.id, required this.kind, required this.text, required this.ts});

  final String id;
  final NotifyKind kind;
  final String text;
  final int ts;

  Map<String, Object> toJson() => {'type': 'notify', 'id': id, 'kind': kind.name, 'text': text, 'ts': ts};

  static Notify fromJson(Map<String, dynamic> json) => Notify(
        id: json['id'] as String,
        kind: NotifyKind.values.byName(json['kind'] as String),
        text: json['text'] as String,
        ts: json['ts'] as int,
      );
}

/// Everything a device can receive from the server.
sealed class ServerEvent {
  const ServerEvent();

  /// Returns null for messages this app version does not understand.
  static ServerEvent? fromJson(Map<String, dynamic> json) {
    try {
      return switch (json['type']) {
        'joined' => Joined(
            code: json['code'] as String,
            peers: Map<String, int>.from(json['peers'] as Map),
          ),
        'peer' => PeerChanged(role: json['role'] as String, connected: json['connected'] as bool),
        'caption' => CaptionReceived(Caption.fromJson(json)),
        'notify' => NotifyReceived(Notify.fromJson(json)),
        'seen' => SeenReceived(json['id'] as String),
        'error' => ServerError(json['message'] as String),
        _ => null,
      };
    } on Object {
      return null;
    }
  }
}

class Joined extends ServerEvent {
  const Joined({required this.code, required this.peers});
  final String code;
  final Map<String, int> peers;
}

class PeerChanged extends ServerEvent {
  const PeerChanged({required this.role, required this.connected});
  final String role;
  final bool connected;
}

class CaptionReceived extends ServerEvent {
  const CaptionReceived(this.caption);
  final Caption caption;
}

class NotifyReceived extends ServerEvent {
  const NotifyReceived(this.notify);
  final Notify notify;
}

class SeenReceived extends ServerEvent {
  const SeenReceived(this.id);
  final String id;
}

class ServerError extends ServerEvent {
  const ServerError(this.message);
  final String message;
}
