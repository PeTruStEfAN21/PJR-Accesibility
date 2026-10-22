import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/ids.dart';
import '../../core/join_link.dart';
import '../../core/protocol.dart';
import '../../core/services.dart';
import '../../core/session_connection.dart';
import '../../core/speech/speech_service.dart';
import '../../core/tts/tts_service.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../../widgets/caption_tile.dart';
import '../../widgets/connection_banner.dart';

/// Runs on the speaker's laptop (Chrome): creates the meeting, shows the join code,
/// captions the room, and shows the participant's raised hand and questions, which
/// it can read out loud.
class PresenterScreen extends StatefulWidget {
  const PresenterScreen({super.key});

  @override
  State<PresenterScreen> createState() => _PresenterScreenState();
}

class _ReceivedMessage {
  _ReceivedMessage(this.notify);
  final Notify notify;
  bool seen = false;

  /// Set once a question was read out loud.
  ReadBy? readBy;
}

class _PresenterScreenState extends State<PresenterScreen> {
  late Future<(JoinLink local, JoinLink public)> _setup;
  SessionConnection? _connection;
  late final SpeechService _speech;
  late final TtsService _tts;
  StreamSubscription<ServerEvent>? _events;
  StreamSubscription<SpeechSegment>? _segments;
  final _messages = <_ReceivedMessage>[];
  Caption? _lastOwnCaption;
  bool _listening = false;
  bool _started = false;
  bool _speaking = false;

  /// „Vorbesc eu”: everything heard is labelled as the speaker's.
  bool _forceSpeaker = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _speech = ServicesScope.of(context).speech;
    _tts = ServicesScope.of(context).tts;
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
        speaker: _currentSpeaker(),
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

  /// Who the laptop is hearing. Voice recognition plugs in here; until then everything is the speaker.
  Speaker _currentSpeaker() => Speaker.coordinator;

  /// Reads the question with the laptop's voice. Captioning stops meanwhile, so the laptop does not
  /// caption itself, and starts again afterwards whether or not the voice worked.
  Future<void> _readAloud(_ReceivedMessage message) async {
    final settings = SettingsScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).presenterReadFailed;
    final wasListening = _listening;
    setState(() => _speaking = true);
    if (wasListening) await _speech.stop();
    final spoken = await _tts.speak(message.notify.text, settings.speechLocaleId);
    if (wasListening) await _speech.start(settings.speechLocaleId);
    if (!mounted) return;
    setState(() => _speaking = false);
    if (spoken) {
      _markRead(message, ReadBy.voice);
    } else {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  void _markRead(_ReceivedMessage message, ReadBy by) {
    _connection?.send(ReadMessage(id: message.notify.id, by: by).toJson());
    setState(() => message.readBy = by);
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
            forceSpeaker: _forceSpeaker,
            onForceSpeaker: (value) => setState(() => _forceSpeaker = value),
          );
          final messages = _MessagesPanel(
            messages: _messages,
            onSeen: _markSeen,
            canSpeak: _tts.canSpeak(SettingsScope.of(context).speechLocaleId),
            speaking: _speaking,
            onReadAloud: _readAloud,
            onReadMyself: (message) => _markRead(message, ReadBy.speaker),
          );

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
  const _JoinPanel({
    required this.link,
    required this.listening,
    required this.lastCaption,
    required this.onToggle,
    required this.forceSpeaker,
    required this.onForceSpeaker,
  });

  final JoinLink link;
  final bool listening;
  final Caption? lastCaption;
  final VoidCallback onToggle;
  final bool forceSpeaker;
  final ValueChanged<bool> onForceSpeaker;

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
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SwitchListTile(
              secondary: const Icon(Icons.record_voice_over),
              title: Text(l10n.presenterForceSpeaker),
              subtitle: Text(l10n.presenterForceSpeakerHint),
              value: forceSpeaker,
              onChanged: onForceSpeaker,
            ),
          ),
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
  const _MessagesPanel({
    required this.messages,
    required this.onSeen,
    required this.canSpeak,
    required this.speaking,
    required this.onReadAloud,
    required this.onReadMyself,
  });

  final List<_ReceivedMessage> messages;
  final void Function(_ReceivedMessage) onSeen;

  /// The laptop has a voice in the spoken language.
  final bool canSpeak;

  /// A question is being read out loud right now.
  final bool speaking;
  final void Function(_ReceivedMessage) onReadAloud;
  final void Function(_ReceivedMessage) onReadMyself;

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
                      if (message.notify.kind == NotifyKind.hand) {
                        return _HandCard(message: message, onSeen: () => onSeen(message));
                      }
                      if (message.notify.kind == NotifyKind.question) {
                        return _QuestionCard(
                          message: message,
                          canSpeak: canSpeak,
                          speaking: speaking,
                          onReadAloud: () => onReadAloud(message),
                          onReadMyself: () => onReadMyself(message),
                        );
                      }
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


/// The participant raised their hand: big, with an icon, never with a sound.
class _HandCard extends StatelessWidget {
  const _HandCard({required this.message, required this.onSeen});

  final _ReceivedMessage message;
  final VoidCallback onSeen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      color: message.seen ? null : theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.front_hand, size: 48, color: message.seen ? null : theme.colorScheme.onErrorContainer),
            const SizedBox(width: 16),
            Expanded(child: Text(l10n.presenterHand, style: theme.textTheme.headlineSmall)),
            const SizedBox(width: 12),
            message.seen
                ? Text(l10n.presenterSeen)
                : FilledButton(onPressed: onSeen, child: Text(l10n.presenterMarkSeen)),
          ],
        ),
      ),
    );
  }
}

/// The participant's typed question, large, with the two ways of reading it out loud.
class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.message,
    required this.canSpeak,
    required this.speaking,
    required this.onReadAloud,
    required this.onReadMyself,
  });

  final _ReceivedMessage message;
  final bool canSpeak;
  final bool speaking;
  final VoidCallback onReadAloud;
  final VoidCallback onReadMyself;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final read = message.readBy != null;
    return Card(
      color: read ? null : theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.contact_support, size: 28),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.presenterQuestionTitle, style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 8),
            Text(message.notify.text, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 12),
            if (read)
              Row(
                children: [
                  const Icon(Icons.check_circle),
                  const SizedBox(width: 8),
                  Text(l10n.presenterRead, style: theme.textTheme.titleMedium),
                ],
              )
            else ...[
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                    onPressed: canSpeak && !speaking ? onReadAloud : null,
                    child: Text(speaking ? l10n.presenterReading : l10n.presenterReadAloud),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56)),
                    onPressed: speaking ? null : onReadMyself,
                    child: Text(l10n.presenterReadMyself),
                  ),
                ],
              ),
              if (!canSpeak) ...[
                const SizedBox(height: 8),
                Text(l10n.presenterNoVoice),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
