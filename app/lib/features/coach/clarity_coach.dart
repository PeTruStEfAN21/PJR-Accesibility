import 'package:flutter/foundation.dart';

import 'voice_activity.dart';

/// The clarity coach's alerts, most important first: the order is the priority when several apply.
enum CoachAlert { overlap, weakMic, tooFast, noPauses, longTalk, noise }

/// Every threshold of the coach in one place (seconds, dB, syllables a second), easy to tune after real
/// meetings. The pace threshold is calibrated on Romanian speech (`ml/voice`, speech rate report).
class CoachThresholds {
  const CoachThresholds({
    this.syllablesPerSecond = 4.75,
    this.rateWindow = 20,
    this.minTalkForRate = 10,
    this.talkGap = 1,
    this.forgetAfter = 60,
    this.pause = 0.4,
    this.unbrokenRun = 12,
    this.unbrokenCount = 2,
    this.unbrokenWindow = 120,
    this.longTalk = 300,
    this.longTalkBreak = 3,
    this.weakSnrDb = 15,
    this.weakLevelDb = -45,
    this.weakWindow = 10,
    this.weakMinVoice = 5,
    this.noiseScore = 0.3,
    this.noiseHold = 5,
    this.noiseAfterSpeech = 60,
    this.overlapHold = 1.5,
    this.speakingOff = 0.4,
    this.minShown = 6,
    this.rest = 180,
  });

  /// Short timings so every alert can be shown within a few minutes (a demo), not for real meetings: pace
  /// over 10 s with a lower threshold, one 8 s stretch without a pause, a minute of talk, alerts back
  /// after 20 s.
  static const demo = CoachThresholds(
    syllablesPerSecond: 4.5,
    rateWindow: 10,
    minTalkForRate: 6,
    unbrokenRun: 8,
    unbrokenCount: 1,
    unbrokenWindow: 60,
    longTalk: 60,
    noiseHold: 3,
    overlapHold: 1,
    minShown: 4,
    rest: 20,
  );

  /// Above this the captions are hard to follow: 170 words a minute, in syllables the analyzer detects in
  /// Romanian speech (ml/voice/reports/2026-10-23-ritm.md).
  final double syllablesPerSecond;

  /// Pace is measured over the last [rateWindow] s of talk, once there are [minTalkForRate] s of it.
  final double rateWindow;
  final double minTalkForRate;

  /// Silences shorter than this stay inside the talk (they count in the pace, like in words a minute).
  final double talkGap;

  /// Talk older than this is forgotten.
  final double forgetAfter;

  /// A pause between ideas; [unbrokenCount] stretches of [unbrokenRun] s without one within
  /// [unbrokenWindow] s raise "make pauses".
  final double pause;
  final double unbrokenRun;
  final int unbrokenCount;
  final double unbrokenWindow;

  /// Talk with breaks shorter than [longTalkBreak] for [longTalk] s raises "leave room for questions".
  final double longTalk;
  final double longTalkBreak;

  /// The voice is weak when, over the last [weakWindow] s of it (at least [weakMinVoice] s), it stands
  /// less than [weakSnrDb] above the room or is quieter than [weakLevelDb].
  final double weakSnrDb;
  final double weakLevelDb;
  final double weakWindow;
  final double weakMinVoice;

  /// Noise around the colleague: a YAMNet noise score of [noiseScore] for [noiseHold] s while quiet,
  /// within [noiseAfterSpeech] s after they last spoke (Echo cannot see the meeting app's mute).
  final double noiseScore;
  final double noiseHold;
  final double noiseAfterSpeech;

  /// Talking at the same time as someone else for this long.
  final double overlapHold;

  /// "Speaking" stays on until this much silence.
  final double speakingOff;

  /// An alert stays at least [minShown] s and does not come back within [rest] s.
  final double minShown;
  final double rest;
}

class _TalkFrame {
  const _TalkFrame(this.time, this.voiced, this.syllable);
  final double time;
  final bool voiced;
  final bool syllable;
}

/// Watches the colleague's own voice, frame by frame, and decides which alert to show.
///
/// Time comes from the sound itself ([VoiceFrame.time]), so it keeps working when the browser tab is in
/// the background. Frames of other voices (`own: false`) only move the clock.
class ClarityCoach extends ChangeNotifier {
  ClarityCoach({this.thresholds = const CoachThresholds()});

  final CoachThresholds thresholds;

  double _now = 0;
  double? _lastOwnVoice;
  bool _speaking = false;

  final _talk = <_TalkFrame>[];
  final _voiceLevels = <(double, double, double)>[]; // (time, db, noiseDb) of own voice frames
  double? _runStart;
  final _unbrokenRuns = <double>[];
  bool _runCounted = false;
  double? _sessionStart;
  double? _noiseSince;
  bool _othersSpeaking = false;
  double? _overlapSince;

  CoachAlert? _current;
  double _shownAt = 0;
  final _restingSince = <CoachAlert, double>{};

  /// The alert to show now, or none.
  CoachAlert? get current => _current;

  /// The colleague is talking now (sent to the others for the overlap alert).
  bool get speaking => _speaking;

  void onFrame(VoiceFrame frame, {bool own = true}) {
    _now = frame.time;
    final voice = own && frame.voiced;
    if (voice) {
      _lastOwnVoice = _now;
      _voiceLevels.add((_now, frame.db, frame.noiseDb));
      _runStart ??= _now;
      _sessionStart ??= _now;
    }
    final sinceVoice = _lastOwnVoice == null ? double.infinity : _now - _lastOwnVoice!;
    if (sinceVoice < thresholds.talkGap) _talk.add(_TalkFrame(_now, voice, own && frame.syllable));
    if (sinceVoice >= thresholds.pause) {
      _runStart = null;
      _runCounted = false;
    }
    if (sinceVoice >= thresholds.longTalkBreak) _sessionStart = null;
    _countUnbrokenRun();
    _forget();
    final wasSpeaking = _speaking;
    _speaking = sinceVoice < thresholds.speakingOff;
    _overlapSince = _speaking && _othersSpeaking ? (_overlapSince ?? _now) : null;
    if (!_decide() && _speaking != wasSpeaking) notifyListeners();
  }

  /// A YAMNet window's noise score (music, typing, fans…) heard at [time] (seconds on the frame clock).
  void onNoise(double score, double time) {
    _now = time;
    final recent = _lastOwnVoice != null && time - _lastOwnVoice! <= thresholds.noiseAfterSpeech;
    _noiseSince = score >= thresholds.noiseScore && !_speaking && recent ? (_noiseSince ?? time) : null;
    _decide();
  }

  /// Whether anyone else in the meeting is speaking (from the other colleagues' pages).
  void onOthersSpeaking(bool any, double time) {
    _now = time;
    _othersSpeaking = any;
    _overlapSince = _speaking && any ? (_overlapSince ?? time) : null;
    _decide();
  }

  void _countUnbrokenRun() {
    final start = _runStart;
    if (start == null || _runCounted || _now - start < thresholds.unbrokenRun) return;
    _runCounted = true;
    _unbrokenRuns.add(_now);
  }

  void _forget() {
    final horizon = _now - thresholds.forgetAfter;
    _talk.removeWhere((f) => f.time < horizon);
    _voiceLevels.removeWhere((v) => v.$1 < _now - thresholds.weakWindow * 6);
    _unbrokenRuns.removeWhere((t) => t < _now - thresholds.unbrokenWindow);
  }

  double? _syllableRate() {
    var talkTime = 0.0;
    var syllables = 0;
    for (final frame in _talk.reversed) {
      if (talkTime >= thresholds.rateWindow) break;
      talkTime += 0.03;
      if (frame.syllable) syllables++;
    }
    if (talkTime < thresholds.minTalkForRate) return null;
    return syllables / talkTime;
  }

  bool _weakVoice() {
    var seconds = 0.0;
    var db = 0.0;
    var noise = 0.0;
    for (final (_, level, room) in _voiceLevels.reversed) {
      if (seconds >= thresholds.weakWindow) break;
      seconds += 0.03;
      db += level;
      noise += room;
    }
    if (seconds < thresholds.weakMinVoice) return false;
    final frames = seconds / 0.03;
    final meanDb = db / frames;
    return meanDb - noise / frames < thresholds.weakSnrDb || meanDb < thresholds.weakLevelDb;
  }

  Set<CoachAlert> _active() {
    final rate = _syllableRate();
    final session = _sessionStart;
    return {
      if (_overlapSince != null && _now - _overlapSince! >= thresholds.overlapHold) CoachAlert.overlap,
      if (_weakVoice()) CoachAlert.weakMic,
      if (rate != null && rate > thresholds.syllablesPerSecond) CoachAlert.tooFast,
      if (_unbrokenRuns.length >= thresholds.unbrokenCount) CoachAlert.noPauses,
      if (session != null && _now - session >= thresholds.longTalk) CoachAlert.longTalk,
      if (_noiseSince != null && _now - _noiseSince! >= thresholds.noiseHold) CoachAlert.noise,
    };
  }

  /// Picks the alert to show; true when it changed (listeners were told).
  bool _decide() {
    final active = _active();
    final before = _current;
    final current = _current;
    if (current != null) {
      final shown = _now - _shownAt;
      final higher = active.any((a) => a.index < current.index && _rested(a));
      if (shown < thresholds.minShown) return false;
      if (active.contains(current) && !higher) return false;
      _restingSince[current] = _now;
      _current = null;
    }
    for (final alert in CoachAlert.values) {
      if (active.contains(alert) && _rested(alert)) {
        _current = alert;
        _shownAt = _now;
        break;
      }
    }
    if (_current == before) return false;
    notifyListeners();
    return true;
  }

  bool _rested(CoachAlert alert) {
    final since = _restingSince[alert];
    return since == null || _now - since >= thresholds.rest;
  }
}
