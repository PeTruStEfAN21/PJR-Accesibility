import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../core/echo_filter.dart';
import '../../core/history/meeting_recorder.dart';
import '../../core/ids.dart';
import '../../core/join_link.dart';
import '../../core/protocol.dart';
import '../../core/server_api.dart';
import '../../core/services.dart';
import '../../core/session_connection.dart';
import '../../core/speech/speech_service.dart';
import '../../core/transcript.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../../widgets/caption_tile.dart';
import '../../widgets/connection_banner.dart';
import 'ask_panel.dart';
import 'meeting_ai.dart';
import 'my_question.dart';
import 'room_questions.dart';

/// The deaf participant's phone: captions by role, questions to the speaker and
/// their answers, quiet messages, and optionally captions of the room from its own
/// microphone.
class ParticipantScreen extends StatefulWidget {
  const ParticipantScreen({super.key, required this.link});
  final JoinLink link;

  @override
  State<ParticipantScreen> createState() => _ParticipantScreenState();
}

class _ParticipantScreenState extends State<ParticipantScreen> {
  final _transcript = Transcript();
  final _echo = EchoFilter();
  final _scroll = ScrollController();
  final _message = TextEditingController();
  final _sentTexts = <String, String>{};
  final _handIds = <String>{};
  final _droppedEchoes = <String>{};

  late final SessionConnection _connection;
  late final SpeechService _speech;
  late final MyQuestion _myQuestion;
  late final RoomQuestions _roomQuestions;
  MyQuestionState? _questionState;
  MeetingRecorder? _recorder;
  StreamSubscription<ServerEvent>? _events;
  StreamSubscription<SpeechSegment>? _segments;
  bool _listening = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final services = ServicesScope.of(context);
    _speech = services.speech;
    _connection = SessionConnection(widget.link, 'participant', channelFactory: services.channelFactory)..connect();
    _events = _connection.events.listen(_onEvent);
    _transcript.addListener(_autoScroll);

    final api = services.api(widget.link.server);
    final speechLocale = SettingsScope.of(context).speechLocaleId;
    _myQuestion = MyQuestion(
      transcript: _transcript,
      // The answer is written in the interface language.
      check: (question, lines) => api.checkAnswer(Localizations.localeOf(context).languageCode, question, lines),
    )..addListener(_onQuestionChanged);
    _roomQuestions = RoomQuestions(
      transcript: _transcript,
      find: (lines) => api.findQuestions(speechLocale.split('-').first, lines),
      lang: speechLocale,
    );
    // Signed-in participants keep the meeting in their account to review later.
    final meetings = services.signedInMeetings;
    if (meetings != null) {
      _recorder = MeetingRecorder(
        store: meetings,
        transcript: _transcript,
        lang: SettingsScope.of(context).speechLocaleId,
        sessionCode: widget.link.code,
      )..start();
    }
  }

  @override
  void dispose() {
    _events?.cancel();
    _segments?.cancel();
    if (_listening) _speech.stop();
    _connection.dispose();
    _myQuestion.dispose();
    _roomQuestions.dispose();
    // stop() detaches from the transcript right away; the last save finishes in the background.
    _recorder?.stop();
    _transcript.dispose();
    _scroll.dispose();
    _message.dispose();
    super.dispose();
  }

  void _onEvent(ServerEvent event) {
    switch (event) {
      case CaptionReceived(:final caption):
        if (caption.speaker == Speaker.coordinator) _echo.coordinatorSpoke(caption.text, clock.now());
        _transcript.upsert(caption);
      case ReadReceived(:final id):
        _myQuestion.markRead(id);
      case SeenReceived(:final id):
        final text = _sentTexts[id];
        if (text != null) _snack(AppLocalizations.of(context).messageSeen(text));
        if (_handIds.contains(id)) _snack(AppLocalizations.of(context).myQuestionHandSeen);
      default:
        break;
    }
  }

  void _onQuestionChanged() {
    final state = _myQuestion.state;
    if (state == MyQuestionState.answered && _questionState != MyQuestionState.answered) {
      HapticFeedback.heavyImpact();
      SemanticsService.sendAnnouncement(
        View.of(context),
        AppLocalizations.of(context).answeredAnnouncement(_myQuestion.result!.answer),
        Directionality.of(context),
        assertiveness: Assertiveness.assertive,
      );
    }
    _questionState = state;
  }

  void _sendHand() {
    final hand = Notify(id: newId(), kind: NotifyKind.hand, text: '', ts: nowMs());
    _handIds.add(hand.id);
    _connection.send(hand.toJson());
    _snack(AppLocalizations.of(context).myQuestionHandSent);
  }

  void _sendQuestion(String text) {
    final notify = Notify(id: newId(), kind: NotifyKind.question, text: text, ts: nowMs());
    _connection.send(notify.toJson());
    _myQuestion.asked(notify.id, notify.text);
  }

  void _autoScroll() {
    if (!SettingsScope.of(context).autoScroll) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _segments?.cancel();
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final settings = SettingsScope.of(context);
    _segments = _speech.segments.listen(_onOwnSpeech);
    final unavailable = AppLocalizations.of(context).speechUnavailable;
    final ok = await _speech.start(settings.speechLocaleId);
    if (!mounted) return;
    if (!ok) {
      await _segments?.cancel();
      if (mounted) _snack(unavailable);
      return;
    }
    setState(() => _listening = true);
  }

  void _onOwnSpeech(SpeechSegment segment) {
    // The phone hears the presenter too; the laptop already captions them.
    if (_droppedEchoes.contains(segment.id) || _echo.isEcho(segment.text, clock.now())) {
      _droppedEchoes.add(segment.id);
      _transcript.remove(segment.id);
      return;
    }
    final caption = Caption(
      id: segment.id,
      speaker: Speaker.public,
      text: segment.text,
      isFinal: segment.isFinal,
      lang: SettingsScope.of(context).speechLocaleId,
      ts: nowMs(),
    );
    _transcript.upsert(caption);
    _connection.send(caption.toJson());
  }

  Future<void> _saveSummary(MeetingSummary summary, String lang) async {
    final recorder = _recorder;
    if (recorder == null) return;
    await recorder.flush();
    final id = recorder.meetingId;
    if (id == null) return;
    try {
      await recorder.store.saveSummary(id, summary, lang);
    } on Object catch (error) {
      debugPrint('Saving the summary failed: $error');
    }
  }

  void _sendNotify(NotifyKind kind, String text) {
    if (text.trim().isEmpty) return;
    final notify = Notify(id: newId(), kind: kind, text: text.trim(), ts: nowMs());
    _sentTexts[notify.id] = notify.text;
    _connection.send(notify.toJson());
    _snack(AppLocalizations.of(context).messageSent(notify.text));
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final services = ServicesScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.captionsLive),
        actions: [
          IconButton(
            tooltip: _listening ? l10n.stopListening : l10n.listenRoom,
            isSelected: _listening,
            icon: const Icon(Icons.mic_none),
            selectedIcon: const Icon(Icons.mic),
            onPressed: _toggleListening,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              final api = services.api(widget.link.server);
              if (value == 'summary') showSummarySheet(context, api, _transcript, onSummary: _saveSummary);
              if (value == 'ask') openAskScreen(context, api, _transcript);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'summary', child: Text(l10n.summaryAction)),
              PopupMenuItem(value: 'ask', child: Text(l10n.askAction)),
            ],
          ),
        ],
      ),
      // The answer card and the bottom bar get a share of the space actually left (keyboard included),
      // so the live captions never disappear on a small phone.
      body: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            ListenableBuilder(
              listenable: _connection,
              builder: (_, _) => ConnectionBanner(
                status: _connection.status,
                detail: _connection.status == ConnectionStatus.connected
                    ? (_connection.peerCount('presenter') > 0 ? l10n.presenterOnline : l10n.presenterOffline)
                    : null,
              ),
            ),
            ListenableBuilder(
              listenable: _myQuestion,
              builder: (_, _) => _myQuestion.state == MyQuestionState.answered
                  ? ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.25),
                      child: AnsweredCard(question: _myQuestion, transcript: _transcript),
                    )
                  : const SizedBox.shrink(),
            ),
            if (_recorder != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l10n.meetingSaving, style: Theme.of(context).textTheme.bodySmall)),
                  ],
                ),
              ),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([_transcript, _roomQuestions]),
                builder: (context, _) =>
                    _CaptionsView(transcript: _transcript, roomQuestions: _roomQuestions, scroll: _scroll),
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.3),
              // A question can only go out while the speaker's laptop is connected.
              child: ListenableBuilder(
                listenable: _connection,
                builder: (_, _) => _MessageBar(
                  controller: _message,
                  onSend: _sendNotify,
                  question: _myQuestion,
                  onHand: _sendHand,
                  onAsk: _sendQuestion,
                  canAsk: _connection.status == ConnectionStatus.connected && _connection.peerCount('presenter') > 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptionsView extends StatelessWidget {
  const _CaptionsView({required this.transcript, required this.roomQuestions, required this.scroll});
  final Transcript transcript;
  final RoomQuestions roomQuestions;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (transcript.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.captionsEmpty, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        ),
      );
    }
    final coordinator = transcript.latest(Speaker.coordinator);
    final numbers = transcript.finalNumbers();
    final captions = transcript.captions;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          // The speaker's latest line has a fixed place at the top, when there is room for it; the same
          // line is also in the list below, so hiding it on a crowded small screen loses nothing.
          if (coordinator != null && constraints.maxHeight >= 220)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: CaptionTile(caption: coordinator, emphasized: true),
            ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: ListView.builder(
                key: const Key('captions'),
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: captions.length,
                itemBuilder: (_, i) => CaptionTile(
                  caption: captions[i],
                  number: numbers[captions[i].id],
                  isQuestion: roomQuestions.isQuestion(captions[i].id),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBar extends StatelessWidget {
  const _MessageBar({
    required this.controller,
    required this.onSend,
    required this.question,
    required this.onHand,
    required this.onAsk,
    required this.canAsk,
  });
  final TextEditingController controller;
  final void Function(NotifyKind kind, String text) onSend;

  /// „Vreau să întreb” and the state of the participant's question.
  final MyQuestion question;
  final VoidCallback onHand;
  final ValueChanged<String> onAsk;
  final bool canAsk;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quick = [
      (NotifyKind.repeat, l10n.quickRepeat, Icons.replay),
      (NotifyKind.slower, l10n.quickSlower, Icons.slow_motion_video),
    ];
    void sendCustom() {
      onSend(NotifyKind.custom, controller.text);
      controller.clear();
    }

    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: AskPanel(
            question: question,
            onHand: onHand,
            onSend: onAsk,
            enabled: canAsk,
            quickMessages: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final (kind, text, icon) in quick)
                      ActionChip(avatar: Icon(icon), label: Text(text), onPressed: () => onSend(kind, text)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(hintText: l10n.customMessageHint),
                        textInputAction: TextInputAction.send,
                        maxLength: 500,
                        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                        onSubmitted: (_) => sendCustom(),
                      ),
                    ),
                    IconButton(tooltip: l10n.send, icon: const Icon(Icons.send), onPressed: sendCustom),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
