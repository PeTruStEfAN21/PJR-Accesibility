import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/ids.dart';
import '../../core/join_link.dart';
import '../../core/protocol.dart';
import '../../core/services.dart';
import '../../core/session_connection.dart';
import '../../core/speech/speech_service.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../../widgets/caption_tile.dart';
import '../../widgets/connection_banner.dart';

/// Runs on the laptop in front of the presenter (Chrome): creates the meeting,
/// shows the join code, captions the presenter and shows silent messages.
class PresenterScreen extends StatefulWidget {
  const PresenterScreen({super.key});

  @override
  State<PresenterScreen> createState() => _PresenterScreenState();
}

class _ReceivedMessage {
  _ReceivedMessage(this.notify);
  final Notify notify;
  bool seen = false;
}

class _PresenterScreenState extends State<PresenterScreen> {
  late Future<(JoinLink local, JoinLink public)> _setup;
  SessionConnection? _connection;
  late final SpeechService _speech;
  StreamSubscription<ServerEvent>? _events;
  StreamSubscription<SpeechSegment>? _segments;
  final _messages = <_ReceivedMessage>[];
  Caption? _lastOwnCaption;
  bool _listening = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _speech = ServicesScope.of(context).speech;
    _setup = _createMeeting();
  }

  Future<(JoinLink, JoinLink)> _createMeeting() async {
    final services = ServicesScope.of(context);
    final server = defaultServer(SettingsScope.of(context));
    final api = services.api(server);
    final code = await api.createSession();
    final publicServer = await api.publicUrl();

    final local = JoinLink(server: server, code: code);
    _connection = SessionConnection(local, 'presenter', channelFactory: services.channelFactory)..connect();
    _events = _connection!.events.listen(_onEvent);
    return (local, JoinLink(server: publicServer, code: code));
  }

  void _retry() => setState(() => _setup = _createMeeting());

  @override
  void dispose() {
    _events?.cancel();
    _segments?.cancel();
    if (_listening) _speech.stop();
    _connection?.dispose();
    super.dispose();
  }

  void _onEvent(ServerEvent event) {
    if (event case NotifyReceived(:final notify)) {
      setState(() => _messages.insert(0, _ReceivedMessage(notify)));
    }
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _segments?.cancel();
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final localeId = SettingsScope.of(context).speechLocaleId;
    _segments = _speech.segments.listen((segment) {
      final caption = Caption(
        id: segment.id,
        speaker: Speaker.coordinator,
        text: segment.text,
        isFinal: segment.isFinal,
        lang: localeId,
        ts: nowMs(),
      );
      _connection?.send(caption.toJson());
      setState(() => _lastOwnCaption = caption);
    });
    final messenger = ScaffoldMessenger.of(context);
    final unavailable = AppLocalizations.of(context).speechUnavailable;
    final ok = await _speech.start(localeId);
    if (!mounted) return;
    if (!ok) {
      await _segments?.cancel();
      messenger.showSnackBar(SnackBar(content: Text(unavailable)));
      return;
    }
    setState(() => _listening = true);
  }

  void _markSeen(_ReceivedMessage message) {
    _connection?.send({'type': 'seen', 'id': message.notify.id});
    setState(() => message.seen = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.presenterTitle)),
      body: FutureBuilder(
        future: _setup,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.presenterCreateError, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _retry, child: Text(l10n.retry)),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final (_, public) = snapshot.data!;
          final connection = _connection!;

          final join = _JoinPanel(
            link: public,
            listening: _listening,
            lastCaption: _lastOwnCaption,
            onToggle: _toggleListening,
          );
          final messages = _MessagesPanel(messages: _messages, onSeen: _markSeen);

          return Column(
            children: [
              ListenableBuilder(
                listenable: connection,
                builder: (_, _) => ConnectionBanner(
                  status: connection.status,
                  detail: l10n.presenterParticipants(connection.peerCount('participant')),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => constraints.maxWidth >= 840
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: SingleChildScrollView(child: join)),
                            const VerticalDivider(width: 1),
                            Expanded(child: messages),
                          ],
                        )
                      : ListView(children: [join, const Divider(), SizedBox(height: 480, child: messages)]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _JoinPanel extends StatelessWidget {
  const _JoinPanel({required this.link, required this.listening, required this.lastCaption, required this.onToggle});

  final JoinLink link;
  final bool listening;
  final Caption? lastCaption;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(l10n.presenterCodeLabel, style: theme.textTheme.titleMedium),
          SelectableText(
            link.code.split('').join(' '),
            semanticsLabel: link.code.split('').join(', '),
            style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: QrImageView(data: link.toUri().toString(), size: 220, semanticsLabel: l10n.joinScan),
          ),
          const SizedBox(height: 8),
          Text(l10n.presenterJoinHint, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(280, 64)),
            onPressed: onToggle,
            icon: Icon(listening ? Icons.stop_circle : Icons.mic),
            label: Text(listening ? l10n.presenterStop : l10n.presenterStart),
          ),
          if (listening) ...[
            const SizedBox(height: 12),
            Text(l10n.presenterListening, textAlign: TextAlign.center),
          ],
          if (lastCaption != null) ...[
            const SizedBox(height: 12),
            CaptionTile(caption: lastCaption!),
          ],
        ],
      ),
    );
  }
}

class _MessagesPanel extends StatelessWidget {
  const _MessagesPanel({required this.messages, required this.onSeen});

  final List<_ReceivedMessage> messages;
  final void Function(_ReceivedMessage) onSeen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Semantics(header: true, child: Text(l10n.presenterNotifications, style: theme.textTheme.titleLarge)),
        ),
        Expanded(
          child: messages.isEmpty
              ? Padding(padding: const EdgeInsets.all(24), child: Text(l10n.presenterNoNotifications))
              : Semantics(
                  liveRegion: true,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final message = messages[i];
                      return Card(
                        color: message.seen ? null : theme.colorScheme.tertiaryContainer,
                        child: ListTile(
                          leading: Icon(message.seen ? Icons.mark_chat_read : Icons.front_hand, size: 32),
                          title: Text(message.notify.text, style: theme.textTheme.titleLarge),
                          trailing: message.seen
                              ? Text(l10n.presenterSeen)
                              : FilledButton(onPressed: () => onSeen(message), child: Text(l10n.presenterMarkSeen)),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
