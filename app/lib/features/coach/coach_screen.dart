import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ids.dart';
import '../../core/join_link.dart';
import '../../core/protocol.dart';
import '../../core/services.dart';
import '../../core/session_connection.dart';
import '../../core/voice/speaker_labeler.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../../theme/echo_style.dart';
import '../../widgets/pressable.dart';
import '../presenter/enroll_view.dart';
import 'clarity_coach.dart';
import 'coach_session.dart';

enum _Stage { setup, enrolling, listening }

const _icons = {
  CoachAlert.overlap: Icons.people_alt_outlined,
  CoachAlert.weakMic: Icons.mic_none,
  CoachAlert.tooFast: Icons.speed,
  CoachAlert.noPauses: Icons.pause_circle_outline,
  CoachAlert.longTalk: Icons.timer_outlined,
  CoachAlert.noise: Icons.volume_off_outlined,
};

/// The same alerts in the window above the meeting, which has no icon font.
const _symbols = {
  CoachAlert.overlap: '👥',
  CoachAlert.weakMic: '🎙️',
  CoachAlert.tooFast: '⏩',
  CoachAlert.noPauses: '⏸️',
  CoachAlert.longTalk: '⏱️',
  CoachAlert.noise: '🔇',
};

/// The alert's words; the long-talk one says how long, from the thresholds in use.
String _alertText(AppLocalizations l10n, CoachAlert alert, CoachThresholds thresholds) => switch (alert) {
      CoachAlert.overlap => l10n.coachAlertOverlap,
      CoachAlert.weakMic => l10n.coachAlertWeakMic,
      CoachAlert.tooFast => l10n.coachAlertTooFast,
      CoachAlert.noPauses => l10n.coachAlertNoPauses,
      CoachAlert.longTalk => l10n.coachAlertLongTalk((thresholds.longTalk / 60).round()),
      CoachAlert.noise => l10n.coachAlertNoise,
    };

String _watchText(AppLocalizations l10n, CoachAlert alert) => switch (alert) {
      CoachAlert.overlap => l10n.coachWatchOverlap,
      CoachAlert.weakMic => l10n.coachWatchWeakMic,
      CoachAlert.tooFast => l10n.coachWatchTooFast,
      CoachAlert.noPauses => l10n.coachWatchNoPauses,
      CoachAlert.longTalk => l10n.coachWatchLongTalk,
      CoachAlert.noise => l10n.coachWatchNoise,
    };

/// The clarity coach, for a hearing colleague in an online meeting: Echo listens to their microphone in
/// this page and shows one discreet alert at a time when a deaf colleague's captions can no longer keep
/// up. Audio never leaves the computer; with a team code only "speaking: on / off" goes to the others.
class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _code = TextEditingController();
  final _id = newId();
  late AppServices _services;
  bool _started = false;

  _Stage _stage = _Stage.setup;
  bool _headphones = false;

  /// Short timings for showing every alert in a few minutes.
  bool _demo = false;
  bool _busy = false;
  String? _error;
  String? _codeNote;
  String? _voiceNote;
  String? _enrollMessage;
  bool _voiceStarted = false;
  SpeakerLabeler? _labeler;

  ClarityCoach? _coach;
  CoachSession? _session;
  SessionConnection? _connection;
  StreamSubscription<ServerEvent>? _events;
  String? _teamCode;

  /// The colleague's own voice is told apart from the meeting in the speakers: headphones or a learned voice.
  bool _trusted = false;
  bool _windowOpen = false;
  String? _lastShown;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _services = ServicesScope.of(context);
  }

  @override
  void dispose() {
    _teardown();
    if (_voiceStarted) _services.voice.stop();
    _code.dispose();
    super.dispose();
  }

  Future<void> _createCode() async {
    final l10n = AppLocalizations.of(context);
    final api = _services.api(defaultServer(SettingsScope.of(context)));
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await api.createSession();
      _code.text = code;
      _codeNote = l10n.coachCodeCreated(code);
    } on Object {
      _error = l10n.coachServerError;
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Loads the speaker model (and opens the microphone) once; null when this browser cannot run it.
  /// Loads the speaker model and opens the microphone; null when this browser cannot run it. Starting is
  /// idempotent and reopens the microphone the coach closes when it stops.
  Future<SpeakerLabeler?> _voiceLabeler() async {
    if (!await _services.voice.start()) return null;
    _voiceStarted = true;
    return _labeler ??= SpeakerLabeler(_services.voice, await _services.voice.loadHead());
  }

  Future<void> _learnVoice() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final labeler = await _voiceLabeler();
    if (!mounted) {
      _services.voice.stop();
      return;
    }
    setState(() {
      _busy = false;
      if (labeler == null) {
        _error = l10n.coachVoiceError;
      } else {
        _enrollMessage = null;
        _stage = _Stage.enrolling;
      }
    });
  }

  /// Deletes the learned voice from this browser; the next start counts every voice again.
  void _forgetVoice() {
    SettingsScope.of(context).update((s) {
      s.coachVoiceprint = null;
      s.coachVoiceprintModel = null;
    });
    _labeler?.voiceprint = null;
    setState(() => _voiceNote = AppLocalizations.of(context).coachVoiceForgotten);
  }

  /// The text was read: learn the colleague's voice from the last 20 s, or ask again.
  Future<void> _finishEnrollment() async {
    final labeler = _labeler!;
    final l10n = AppLocalizations.of(context);
    final settings = SettingsScope.of(context);
    final result = await labeler.enroll(_services.voice.recent(const Duration(seconds: 20)));
    if (!mounted) return;
    if (result == EnrollResult.ok) {
      settings.update((s) {
        s.coachVoiceprint = labeler.voiceprint!.toList();
        s.coachVoiceprintModel = labeler.head.model;
      });
      _voiceNote = null;
    }
    setState(() {
      switch (result) {
        case EnrollResult.ok:
          _stage = _Stage.setup;
        case EnrollResult.tooLittleSpeech:
          _enrollMessage = l10n.enrollTooShort;
        case EnrollResult.failed:
          _enrollMessage = l10n.enrollFailed;
      }
    });
  }

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context);
    final settings = SettingsScope.of(context);
    final code = _code.text.trim().toUpperCase();
    if (code.isNotEmpty && !JoinLink.isValidCode(code)) {
      setState(() => _error = l10n.coachCodeInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    // A learned voice from another speaker model means nothing to this one: then the voice is not used.
    SpeakerLabeler? labeler;
    final saved = settings.coachVoiceprint;
    if (saved != null) {
      labeler = await _voiceLabeler();
      if (!mounted) {
        _services.voice.stop();
        return;
      }
      if (labeler != null && settings.coachVoiceprintModel == labeler.head.model) {
        labeler.voiceprint = Float32List.fromList(saved);
      } else {
        labeler = null;
      }
    }
    final microphone = await _services.coachAudio.start();
    if (!mounted) {
      _services.coachAudio.stop();
      return;
    }
    if (!microphone) {
      setState(() {
        _busy = false;
        _error = l10n.coachMicError;
      });
      return;
    }
    final coach = ClarityCoach(thresholds: _demo ? CoachThresholds.demo : const CoachThresholds())..addListener(_onCoach);
    _trusted = _headphones || labeler != null;
    _session = CoachSession(_services.coachAudio, coach, labeler: labeler, onSpeaking: _onSpeaking)..start();
    if (code.isNotEmpty) _join(code, settings);
    setState(() {
      _coach = coach;
      _busy = false;
      _stage = _Stage.listening;
    });
  }

  void _join(String code, AppSettings settings) {
    final link = JoinLink(server: defaultServer(settings), code: code);
    final connection = SessionConnection(link, 'colleague', channelFactory: _services.channelFactory)
      ..addListener(_onConnection)
      ..connect();
    _events = connection.events.listen(_onEvent);
    _connection = connection;
    _teamCode = code;
  }

  void _onEvent(ServerEvent event) {
    final session = _session;
    if (session == null) return;
    switch (event) {
      case Joined():
        // After a reconnection nobody's state is known; ours goes out again if we are talking.
        session.forgetOthers();
        if (_coach?.speaking ?? false) _onSpeaking(true);
      case PeerChanged(role: 'colleague', connected: false):
        session.forgetOthers();
      case SpeakingReceived(:final id, :final active) when _trusted:
        session.otherSpeaking(id, active);
      default:
        break;
    }
  }

  void _onSpeaking(bool speaking) {
    if (!_trusted) return;
    _connection?.send(SpeakingMessage(id: _id, active: speaking, ts: nowMs()).toJson());
  }

  void _onConnection() => setState(() {});

  void _onCoach() {
    setState(() {});
    _showInWindow();
  }

  void _showInWindow() {
    if (!_windowOpen) return;
    final l10n = AppLocalizations.of(context);
    final coach = _coach;
    final alert = coach?.current;
    final text = alert == null || coach == null ? l10n.coachAllGood : _alertText(l10n, alert, coach.thresholds);
    if (text == _lastShown) return;
    _lastShown = text;
    _services.alertWindow.show(text, alert == null ? '✅' : _symbols[alert]!, alert: alert != null);
  }

  Future<void> _openWindow() async {
    final l10n = AppLocalizations.of(context);
    final opened = await _services.alertWindow.open(
      title: l10n.coachPipTitle,
      language: Localizations.localeOf(context).languageCode,
      textScale: MediaQuery.textScalerOf(context).scale(1),
      onClosed: () {
        if (mounted && _windowOpen) setState(() => _windowOpen = false);
      },
    );
    if (!mounted) return;
    setState(() => _windowOpen = opened);
    _lastShown = null;
    _showInWindow();
  }

  void _closeWindow() {
    setState(() => _windowOpen = false);
    _services.alertWindow.close();
  }

  void _stop() {
    _teardown();
    setState(() => _stage = _Stage.setup);
  }

  void _teardown() {
    _session?.stop();
    _session = null;
    _coach
      ?..removeListener(_onCoach)
      ..dispose();
    _coach = null;
    _services.coachAudio.stop();
    _events?.cancel();
    _events = null;
    _connection
      ?..removeListener(_onConnection)
      ..dispose();
    _connection = null;
    _teamCode = null;
    if (_windowOpen) {
      _windowOpen = false;
      _services.alertWindow.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = EchoPalette.of(context);
    return Scaffold(
      backgroundColor: palette.ground,
      appBar: AppBar(
        backgroundColor: palette.ground,
        foregroundColor: palette.text,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(l10n.coachTitle),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: switch (_stage) {
              _Stage.setup => _setup(context),
              _Stage.enrolling => ListView(
                  children: [
                    EnrollView(onRecorded: _finishEnrollment, message: _enrollMessage, intro: l10n.coachEnrollIntro),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 24),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton(
                          style: EchoButtons.link(palette, flush: true),
                          onPressed: () => setState(() => _stage = _Stage.setup),
                          child: Text(l10n.cancel),
                        ),
                      ),
                    ),
                  ],
                ),
              _Stage.listening => _listening(context),
            },
          ),
        ),
      ),
    );
  }

  Widget _setup(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = EchoPalette.of(context);
    final voiceLearned = SettingsScope.of(context).coachVoiceprint != null;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: palette.muted);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(l10n.coachIntro, style: theme.textTheme.bodyLarge?.copyWith(color: palette.text)),
        const SizedBox(height: 24),
        _Panel(
          title: l10n.coachTeam,
          children: [
            TextField(
              controller: _code,
              decoration: InputDecoration(labelText: l10n.coachCodeLabel),
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(6),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                style: EchoButtons.link(palette, flush: true),
                onPressed: _busy ? null : _createCode,
                child: Text(l10n.coachCreateCode),
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.coachCodeHint, style: muted),
            if (_codeNote case final note?) ...[
              const SizedBox(height: 8),
              Semantics(liveRegion: true, child: Text(note, style: theme.textTheme.titleMedium?.copyWith(color: palette.text))),
            ],
          ],
        ),
        const SizedBox(height: 16),
        _Panel(
          title: l10n.coachMicrophone,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _headphones,
              onChanged: (value) => setState(() => _headphones = value),
              title: Text(l10n.coachHeadphones),
              subtitle: Text(l10n.coachHeadphonesHint),
            ),
            const SizedBox(height: 8),
            if (voiceLearned)
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, color: palette.accent),
                  Text(l10n.coachVoiceLearned, style: theme.textTheme.titleMedium?.copyWith(color: palette.text)),
                  TextButton(
                    style: EchoButtons.link(palette),
                    onPressed: _busy ? null : _learnVoice,
                    child: Text(l10n.coachRelearnVoice),
                  ),
                  TextButton(
                    style: EchoButtons.link(palette),
                    onPressed: _busy ? null : _forgetVoice,
                    child: Text(l10n.coachForgetVoice),
                  ),
                ],
              )
            else ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48), foregroundColor: palette.text),
                  onPressed: _busy ? null : _learnVoice,
                  icon: const Icon(Icons.record_voice_over_outlined),
                  label: Text(l10n.coachLearnVoice),
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.coachVoiceHint, style: muted),
            ],
            const SizedBox(height: 8),
            // A voice fingerprint is biometric data: say where it is kept, before and after learning it.
            Text(l10n.coachVoiceStored, style: muted),
            if (_voiceNote case final note?) ...[
              const SizedBox(height: 8),
              Semantics(liveRegion: true, child: Text(note, style: theme.textTheme.titleMedium?.copyWith(color: palette.text))),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          value: _demo,
          onChanged: (value) => setState(() => _demo = value),
          title: Text(l10n.coachDemo),
          subtitle: Text(l10n.coachDemoHint),
        ),
        if (_error case final error?) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(error, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error)),
          ),
        ],
        const SizedBox(height: 24),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Pressable(
            child: FilledButton(
              style: EchoButtons.primary(palette),
              onPressed: _busy ? null : _start,
              child: Text(l10n.coachStart),
            ),
          ),
        ),
      ],
    );
  }

  Widget _listening(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = EchoPalette.of(context);
    final current = _coach?.current;
    final window = _services.alertWindow;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: palette.muted);
    final connection = _connection;
    final team = switch (connection?.status) {
      null => l10n.coachNoTeam,
      ConnectionStatus.closed => l10n.coachUnknownCode(_teamCode!),
      ConnectionStatus.reconnecting => l10n.coachReconnecting,
      _ => l10n.coachTeamStatus(_teamCode!, (connection!.peerCount('colleague') - 1).clamp(0, 999)),
    };
    final notes = [
      team,
      if (!_trusted) l10n.coachApproximate,
      if (!(_session?.noiseAvailable ?? true)) l10n.coachNoNoise,
    ];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _AlertPanel(alert: current, thresholds: _coach?.thresholds ?? const CoachThresholds()),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _windowOpen
              ? TextButton(style: EchoButtons.link(palette, flush: true), onPressed: _closeWindow, child: Text(l10n.coachPipClose))
              : Pressable(
                  child: FilledButton(
                    style: EchoButtons.primary(palette),
                    onPressed: window.supported ? _openWindow : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.picture_in_picture_alt_outlined),
                        const SizedBox(width: 8),
                        Flexible(child: Text(l10n.coachPip)),
                      ],
                    ),
                  ),
                ),
        ),
        if (!window.supported) ...[
          const SizedBox(height: 8),
          Text(l10n.coachPipUnsupported, style: muted),
        ],
        const SizedBox(height: 16),
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 20, color: palette.muted),
                const SizedBox(width: 8),
                Expanded(child: Text(note, style: muted)),
              ],
            ),
          ),
        const SizedBox(height: 16),
        _Panel(
          title: l10n.coachWatching,
          children: [
            for (final alert in CoachAlert.values)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(_icons[alert], color: alert == current ? palette.text : palette.muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _watchText(l10n, alert),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: palette.text,
                          fontWeight: alert == current ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(style: EchoButtons.link(palette, flush: true), onPressed: _stop, child: Text(l10n.coachStop)),
        ),
      ],
    );
  }
}

/// The alert of the moment, large: icon and text, read out by screen readers when it changes.
class _AlertPanel extends StatelessWidget {
  const _AlertPanel({required this.alert, required this.thresholds});

  final CoachAlert? alert;
  final CoachThresholds thresholds;

  /// The amber of Echo's warnings, with black on it.
  static const _amber = Color(0xFFFFC233);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = EchoPalette.of(context);
    final highContrast = SettingsScope.of(context).highContrast;
    final alert = this.alert;
    final background = alert == null || highContrast ? palette.accentTint : _amber;
    final foreground = alert == null || highContrast ? palette.text : Colors.black;
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        border: highContrast ? Border.all(color: palette.border, width: alert == null ? 2 : 4) : null,
      ),
      child: Row(
        children: [
          Icon(alert == null ? Icons.check_circle_outline : _icons[alert], size: 44, color: foreground),
          const SizedBox(width: 16),
          Expanded(
            child: Semantics(
              container: true,
              liveRegion: true,
              child: Text(
                alert == null ? l10n.coachAllGood : _alertText(l10n, alert, thresholds),
                style: theme.textTheme.headlineSmall?.copyWith(color: foreground, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tonal panel with a small heading, as on the home screen.
class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = EchoPalette.of(context);
    final highContrast = SettingsScope.of(context).highContrast;
    // A Material, not a coloured box: the headphones switch draws its highlight on it.
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: highContrast ? BorderSide(color: palette.border, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: palette.text, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
