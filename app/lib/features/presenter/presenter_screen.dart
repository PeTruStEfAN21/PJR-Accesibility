import 'dart:async';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/ids.dart';
import '../../core/join_link.dart';
import '../../core/protocol.dart';
import '../../core/services.dart';
import '../../core/session_connection.dart';
import '../../core/speech/speech_service.dart';
import '../../core/tts/tts_service.dart';
import '../../core/voice/speaker_labeler.dart';
import '../../core/voice/voice_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../../widgets/caption_tile.dart';
import '../../widgets/connection_banner.dart';
import 'enroll_view.dart';
import 'test_meeting.dart';
import 'test_meeting_review.dart';

/// Runs on the speaker's laptop (Chrome): learns the speaker's voice, creates the meeting,
/// shows the join code, captions the room labelling each line by voice (speaker or room),
/// and shows the participant's raised hand and questions, which it can read out loud.
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

/// Where voice recognition is: starting, waiting for the speaker to read the text, working, or not
/// available in this browser (then every line is the speaker's).
enum _VoiceStage { checking, enrolling, ready, unavailable }

class _PresenterScreenState extends State<PresenterScreen> {
  late Future<(JoinLink local, JoinLink public)> _setup;
  SessionConnection? _connection;
  late final SpeechService _speech;
  late final TtsService _tts;
  late final VoiceEngine _voice;
  SpeakerLabeler? _labeler;
  _VoiceStage _voiceStage = _VoiceStage.checking;
  String? _enrollMessage;
  bool _justEnrolled = false;

  /// The last enrollment recording of this session (a test meeting archive starts with it).
  Float32List? _enrollmentAudio;

  /// On while a test meeting is being recorded.
  TestMeetingRecorder? _testMeeting;

  /// How the last final line was labelled, shown under it (for tuning in a real room).
  String? _lastDecision;
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
    _voice = ServicesScope.of(context).voice;
    _setup = _createMeeting();
    _startVoice();
  }

  Future<void> _startVoice() async {
    final settings = SettingsScope.of(context);
    final saved = settings.voiceprint;
    if (!await _voice.start()) {
      if (mounted) setState(() => _voiceStage = _VoiceStage.unavailable);
      return;
    }
    final labeler = SpeakerLabeler(_voice, await _voice.loadHead())..forceSpeaker = _forceSpeaker;
    if (saved != null && settings.voiceprintModel == labeler.head.model) {
      labeler.voiceprint = Float32List.fromList(saved);
    }
    if (!mounted) return;
    setState(() {
      _labeler = labeler;
      _voiceStage = labeler.enrolled ? _VoiceStage.ready : _VoiceStage.enrolling;
    });
  }

  /// The enrollment text was read: learn the voice from the last 20 s, or ask again.
  Future<void> _finishEnrollment() async {
    final labeler = _labeler!;
    final l10n = AppLocalizations.of(context);
    final settings = SettingsScope.of(context);
    final samples = _voice.recent(const Duration(seconds: 20));
    final result = await labeler.enroll(samples);
    if (!mounted) return;
    if (result == EnrollResult.ok) {
      settings.update((s) {
        s.voiceprint = labeler.voiceprint!.toList();
        s.voiceprintModel = labeler.head.model;
      });
      _enrollmentAudio = samples;
      _testMeeting?.setEnrollment(samples);
    }
    setState(() {
      switch (result) {
        case EnrollResult.ok:
          _voiceStage = _VoiceStage.ready;
          _justEnrolled = true;
          _enrollMessage = null;
        case EnrollResult.tooLittleSpeech:
          _enrollMessage = l10n.enrollTooShort;
        case EnrollResult.failed:
          _enrollMessage = l10n.enrollFailed;
      }
    });
  }

  /// A test meeting starts with this session's enrollment recording; without one, the voice is learned again.
  void _toggleTestMeeting(bool on) {
    final labeler = _labeler;
    if (!on || labeler == null) {
      setState(() => _testMeeting = null);
      return;
    }
    final recorder = TestMeetingRecorder(model: labeler.head.model);
    final audio = _enrollmentAudio;
    if (audio != null) recorder.setEnrollment(audio);
    setState(() => _testMeeting = recorder);
    if (audio == null) _relearnVoice();
  }

  void _relearnVoice() {
    _labeler?.voiceprint = null;
    SettingsScope.of(context).update((s) => s.voiceprint = null);
    setState(() {
      _voiceStage = _VoiceStage.enrolling;
      _justEnrolled = false;
      _enrollMessage = null;
    });
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
    _voice.stop();
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
      // Not awaited: nothing depends on it, and the stop should not wait for the stream.
      unawaited(_segments?.cancel());
      await _speech.stop();
      setState(() => _listening = false);
      final recorder = _testMeeting;
      if (recorder != null && recorder.lines.isNotEmpty && mounted) {
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => TestMeetingReview(recorder: recorder, play: _voice.play),
        ));
      }
      return;
    }
    final localeId = SettingsScope.of(context).speechLocaleId;
    _segments = _speech.segments.listen((segment) async {
      // A final line is judged on its own audio; a partial one keeps the last decided label.
      final labeler = _labeler;
      final judged = labeler != null && segment.isFinal ? await labeler.judgeFinal(clock.now()) : null;
      final speaker = judged?.speaker ?? labeler?.current ?? Speaker.coordinator;
      if (!mounted) return;
      if (judged != null) {
        _testMeeting?.add(
          id: segment.id,
          text: segment.text,
          predicted: speaker,
          score: judged.score,
          reason: judged.reason.name,
          clip: judged.clip,
        );
      }
      if (segment.isFinal) _lastDecision = _describe(labeler, judged, speaker);
      final caption = Caption(
        id: segment.id,
        speaker: speaker,
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
    _labeler?.startWindowAt(clock.now());
    setState(() => _listening = true);
  }

  String _describe(SpeakerLabeler? labeler, Judgement? judged, Speaker speaker) {
    final l10n = AppLocalizations.of(context);
    if (labeler == null || judged == null) return l10n.voiceDiagOff;
    switch (judged.reason) {
      case JudgeReason.notEnrolled:
        return l10n.voiceDiagNotLearned;
      case JudgeReason.forced:
        return l10n.voiceDiagForced;
      case JudgeReason.tooShort:
        return l10n.voiceDiagShort;
      case JudgeReason.modelError:
        return l10n.voiceDiagError;
      case JudgeReason.judged:
        break;
    }
    final number = NumberFormat('0.00', Localizations.localeOf(context).toString());
    return l10n.voiceDiagScore(
      number.format(judged.score!),
      number.format(labeler.head.cosineThreshold),
      speakerLabel(l10n, speaker),
    );
  }

  /// Reads the question with the laptop's voice. Captioning stops meanwhile, so the laptop does not
  /// caption itself, and starts again afterwards whether or not the voice worked.
  Future<void> _readAloud(_ReceivedMessage message) async {
    final settings = SettingsScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).presenterReadFailed;
    final text = message.notify.text;
    // The browser's voice sometimes never reports the end: give up after a generous time for the text.
    final limit = Duration(milliseconds: 5000 + 120 * text.length);
    final wasListening = _listening;
    setState(() => _speaking = true);
    if (wasListening) await _speech.stop();
    var spoken = false;
    try {
      spoken = await _tts.speak(text, settings.speechLocaleId).timeout(limit, onTimeout: () {
        _tts.cancel();
        return false;
      });
    } on Object {
      spoken = false;
    } finally {
      // Captioning restarts whatever happened, unless the speaker pressed Stop meanwhile; the next line is
      // judged only on what is heard after the laptop's voice.
      if (wasListening && _listening) await _speech.start(settings.speechLocaleId);
      _labeler?.startWindowAt(clock.now());
    }
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
            lastDecision: _lastDecision,
            onToggle: _toggleListening,
            forceSpeaker: _forceSpeaker,
            onForceSpeaker: (value) => setState(() {
              _forceSpeaker = value;
              _labeler?.forceSpeaker = value;
            }),
            voiceNote: switch (_voiceStage) {
              _VoiceStage.unavailable => l10n.voiceUnavailable,
              _VoiceStage.ready when _justEnrolled => l10n.enrollDone,
              _ => null,
            },
            onRelearn: _voiceStage == _VoiceStage.ready ? _relearnVoice : null,
            testMeeting: _testMeeting != null,
            onTestMeeting: _voiceStage == _VoiceStage.ready && !_listening ? _toggleTestMeeting : null,
          );
          final left = switch (_voiceStage) {
            _VoiceStage.checking => const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
            _VoiceStage.enrolling => EnrollView(onRecorded: _finishEnrollment, message: _enrollMessage),
            _ => join,
          };
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
                            Expanded(child: SingleChildScrollView(child: left)),
                            const VerticalDivider(width: 1),
                            Expanded(child: messages),
                          ],
                        )
                      : ListView(children: [left, const Divider(), SizedBox(height: 480, child: messages)]),
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
    required this.lastDecision,
    required this.onToggle,
    required this.forceSpeaker,
    required this.onForceSpeaker,
    required this.voiceNote,
    required this.onRelearn,
    required this.testMeeting,
    required this.onTestMeeting,
  });

  final JoinLink link;
  final bool listening;
  final Caption? lastCaption;
  final String? lastDecision;
  final VoidCallback onToggle;
  final bool forceSpeaker;
  final ValueChanged<bool> onForceSpeaker;

  /// How voice recognition is doing („Vocea ta e învățată”, or that it does not work here).
  final String? voiceNote;

  /// „Reînvață vocea”; null when there is no voice recognition.
  final VoidCallback? onRelearn;

  /// „Meeting de test”; [onTestMeeting] is null while captioning runs or without voice recognition.
  final bool testMeeting;
  final ValueChanged<bool>? onTestMeeting;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (voiceNote case final note?)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.record_voice_over),
                    const SizedBox(width: 8),
                    Flexible(child: Text(note, style: theme.textTheme.titleMedium)),
                  ],
                ),
              ),
            ),
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
          if (onTestMeeting != null || testMeeting)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SwitchListTile(
                secondary: const Icon(Icons.science),
                title: Text(l10n.testMeeting),
                subtitle: Text(l10n.testMeetingHint),
                value: testMeeting,
                onChanged: onTestMeeting,
              ),
            ),
          if (onRelearn != null)
            TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onRelearn,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.relearnVoice),
            ),
          if (lastCaption != null) ...[
            const SizedBox(height: 12),
            CaptionTile(caption: lastCaption!),
            if (lastDecision case final decision?) Text(decision, style: theme.textTheme.bodySmall),
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
