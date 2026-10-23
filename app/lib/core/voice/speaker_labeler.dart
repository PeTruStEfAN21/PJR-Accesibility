import 'dart:math';
import 'dart:typed_data';

import '../protocol.dart';
import 'voice_engine.dart';
import 'voice_head.dart';

enum EnrollResult { ok, tooLittleSpeech, failed }

/// Why a line got its label: judged by voice, or not judged (and why).
enum JudgeReason { judged, tooShort, notEnrolled, forced, modelError }

/// The decision for one final caption: who said it, how sure (null when not judged by voice), why, and the
/// audio it was decided on.
typedef Judgement = ({Speaker speaker, double? score, JudgeReason reason, Float32List clip});

const _rate = 16000;

/// Decides, for each final caption, whether the speaker said it or someone in the room.
///
/// The speaker's voice is learned once (enrollment) and refined during the meeting from lines that are
/// clearly theirs. For each final caption the audio heard since the previous one (1.5–8 s), without its
/// quiet edges, is embedded and compared with it. Lines are judged one at a time, each on the audio
/// taken when it ended; a model error keeps the line with the previous label.
class SpeakerLabeler {
  SpeakerLabeler(this.engine, this.head);

  static const _minWindow = Duration(milliseconds: 1500);
  static const _maxWindow = Duration(seconds: 8);

  final VoiceEngine engine;
  final VoiceHead head;

  /// „Vorbesc eu”: everything is the speaker's.
  bool forceSpeaker = false;

  /// The learned voice, unit length; set it to restore a saved one.
  Float32List? voiceprint;

  /// The voice as enrolled: adaptation never moves [voiceprint] far from it.
  Float32List? _anchor;

  DateTime? _lastFinal;
  Speaker _current = Speaker.coordinator;
  Future<Judgement>? _pending;

  bool get enrolled => voiceprint != null;

  /// The label for partial captions: the last decided one.
  Speaker get current => forceSpeaker ? Speaker.coordinator : _current;

  Future<EnrollResult> enroll(Float32List samples) async {
    final voiced = voicedOnly(samples);
    if (voiced.length < head.enrollMinVoicedMs * _rate ~/ 1000) return EnrollResult.tooLittleSpeech;
    final window = head.windowMs * _rate ~/ 1000;
    try {
      final vectors = [
        for (var start = 0; start + window <= voiced.length; start += window)
          await engine.embed(Float32List.sublistView(voiced, start, start + window)),
      ];
      voiceprint = _normalized(_mean(vectors));
      _anchor = null;
      _current = Speaker.coordinator;
      return EnrollResult.ok;
    } on Object {
      return EnrollResult.failed;
    }
  }

  /// The next final line is judged only on audio heard after [time] (e.g. when the laptop stops
  /// speaking, or captioning starts).
  void startWindowAt(DateTime time) => _lastFinal = time;

  Future<Speaker> labelFinal(DateTime now) async => (await judgeFinal(now)).speaker;

  Future<Judgement> judgeFinal(DateTime now) {
    final last = _lastFinal;
    _lastFinal = now;
    final since = last == null ? _maxWindow : now.difference(last);
    final window = since < _minWindow ? _minWindow : (since > _maxWindow ? _maxWindow : since);
    // The audio is taken now, so a line judged later still gets its own sound.
    final clip = enrolled ? trimSilence(engine.recent(window)) : Float32List(0);
    final previous = _pending;
    final judged = () async {
      if (previous != null) await previous;
      return _judge(clip);
    }();
    _pending = judged;
    return judged;
  }

  Future<Judgement> _judge(Float32List clip) async {
    if (!enrolled) return (speaker: Speaker.coordinator, score: null, reason: JudgeReason.notEnrolled, clip: clip);
    if (forceSpeaker) return (speaker: Speaker.coordinator, score: null, reason: JudgeReason.forced, clip: clip);
    final voiced = voicedOnly(clip).length;
    if (voiced < head.minVoicedMs * _rate ~/ 1000) {
      return (speaker: current, score: null, reason: JudgeReason.tooShort, clip: clip);
    }
    final Float32List vector;
    try {
      vector = await engine.embed(clip);
    } on Object {
      return (speaker: current, score: null, reason: JudgeReason.modelError, clip: clip);
    }
    final score = cosine(vector, voiceprint!);
    _current = head.isSpeaker(score) ? Speaker.coordinator : Speaker.public;
    if (head.probability(score) >= head.adaptThreshold && voiced >= head.adaptMinVoicedMs * _rate ~/ 1000) {
      _adapt(vector);
    }
    return (speaker: current, score: score, reason: JudgeReason.judged, clip: clip);
  }

  /// Moves the learned voice a little toward a line that is clearly the speaker's: the room, the distance
  /// and the speaker's voice that day are learned as the meeting goes on.
  void _adapt(Float32List vector) {
    final anchor = _anchor ??= Float32List.fromList(voiceprint!);
    final moved = _normalized(Float32List.fromList([
      for (var i = 0; i < vector.length; i++) (1 - head.adaptRate) * voiceprint![i] + head.adaptRate * vector[i],
    ]));
    if (cosine(moved, anchor) >= head.adaptMinCosine) voiceprint = moved;
  }
}

/// RMS of each 30 ms frame. A frame is voiced when it stands about 6 dB above the clip's noise floor (its
/// quietest fifth), and in any case within [relativeDb] of the loudest frame and above about -60 dBFS.
/// Frames within 6 dB of the loudest always count, so a clip that is all voice stays voice. 6 dB, not 12:
/// the raw laptop microphone hears most syllables only about 10 dB above the room.
List<bool> _voicedFrames(Float32List samples, int frame, double relativeDb) {
  final energies = <double>[];
  for (var start = 0; start < samples.length; start += frame) {
    final end = min(start + frame, samples.length);
    var sum = 0.0;
    for (var i = start; i < end; i++) {
      sum += samples[i] * samples[i];
    }
    energies.add(sum / (end - start));
  }
  if (energies.isEmpty) return const [];
  final loudest = energies.reduce(max);
  final sorted = [...energies]..sort();
  final noise = sorted[(sorted.length * 0.2).floor()];
  final aboveNoise = min(noise * pow(10, 6 / 10), loudest * pow(10, -6 / 10));
  final floor = max(max(aboveNoise, loudest * pow(10, relativeDb / 10)), 1e-6);
  return [for (final e in energies) e >= floor];
}

/// The clip without its quiet beginning and end.
Float32List trimSilence(Float32List samples, {int frameMs = 30, double relativeDb = -35}) {
  final frame = frameMs * _rate ~/ 1000;
  final voiced = _voicedFrames(samples, frame, relativeDb);
  final first = voiced.indexOf(true);
  if (first == -1) return Float32List(0);
  final last = voiced.lastIndexOf(true);
  return Float32List.sublistView(samples, first * frame, min((last + 1) * frame, samples.length));
}

/// Only the voiced frames of the clip, joined (for enrollment, where pauses say nothing about the voice).
Float32List voicedOnly(Float32List samples, {int frameMs = 30, double relativeDb = -35}) {
  final frame = frameMs * _rate ~/ 1000;
  final voiced = _voicedFrames(samples, frame, relativeDb);
  final out = BytesBuilder(copy: false);
  for (var i = 0; i < voiced.length; i++) {
    if (!voiced[i]) continue;
    final part = Float32List.fromList(Float32List.sublistView(samples, i * frame, min((i + 1) * frame, samples.length)));
    out.add(part.buffer.asUint8List());
  }
  return out.takeBytes().buffer.asFloat32List();
}

double cosine(Float32List a, Float32List b) {
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  return na == 0 || nb == 0 ? 0 : dot / sqrt(na * nb);
}

Float32List _mean(List<Float32List> vectors) {
  final out = Float32List(vectors.first.length);
  for (final v in vectors) {
    for (var i = 0; i < out.length; i++) {
      out[i] += v[i] / vectors.length;
    }
  }
  return out;
}

Float32List _normalized(Float32List v) {
  var norm = 0.0;
  for (final x in v) {
    norm += x * x;
  }
  norm = sqrt(norm);
  return Float32List.fromList([for (final x in v) x / norm]);
}
