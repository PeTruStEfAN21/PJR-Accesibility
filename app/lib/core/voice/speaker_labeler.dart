import 'dart:math';
import 'dart:typed_data';

import '../protocol.dart';
import 'voice_engine.dart';
import 'voice_head.dart';

enum EnrollResult { ok, tooLittleSpeech, failed }

const _rate = 16000;

/// Decides, for each final caption, whether the speaker said it or someone in the room.
///
/// The speaker's voice is learned once (enrollment). For each final caption the audio heard since the
/// previous final caption (1.5–8 s), without the quiet edges, is embedded and compared with it.
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

  DateTime? _lastFinal;
  Speaker _current = Speaker.coordinator;

  /// Similarity of the last judged utterance with the learned voice (null when it was not judged).
  double? lastScore;

  /// The audio the last label was decided on (kept for test meetings).
  Float32List? lastClip;

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
      _current = Speaker.coordinator;
      return EnrollResult.ok;
    } on Object {
      return EnrollResult.failed;
    }
  }

  Future<Speaker> labelFinal(DateTime now) async {
    final last = _lastFinal;
    _lastFinal = now;
    final since = last == null ? _maxWindow : now.difference(last);
    final window = since < _minWindow ? _minWindow : (since > _maxWindow ? _maxWindow : since);
    if (!enrolled) return Speaker.coordinator;

    final clip = trimSilence(engine.recent(window));
    lastClip = clip;
    lastScore = null;
    if (forceSpeaker) return Speaker.coordinator;
    if (clip.length < head.minVoicedMs * _rate ~/ 1000) return _current;

    final score = cosine(await engine.embed(clip), voiceprint!);
    lastScore = score;
    _current = head.isSpeaker(score) ? Speaker.coordinator : Speaker.public;
    return current;
  }
}

/// RMS of each 30 ms frame; a frame is voiced when it is within [relativeDb] of the loudest frame and
/// above about -60 dBFS (so a silent clip stays silent).
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
  final floor = max(loudest * pow(10, relativeDb / 10), 1e-6);
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
