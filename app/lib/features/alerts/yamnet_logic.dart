import 'dart:math' as math;
import 'dart:typed_data';

import 'location_sounds.dart';
import 'sound_alert.dart';

/// YAMNet listens at 16 kHz in windows of 0.975 s.
const yamnetSampleRate = 16000;
const yamnetWindow = 15600;

/// Half a second between windows, so "two windows in a row" takes about 1.5 s.
const yamnetHop = 8000;

/// Score a known class needs in each of the windows.
const kindThreshold = 0.3;

/// Cosine similarity a learned sound needs. Picked on synthetic sounds; tune on the phone.
const locationThreshold = 0.8;

/// YAMNet classes we alert on, by `display_name` in yamnet_class_map.csv.
const yamnetClasses = <String, SoundKind>{
  'Fire alarm': SoundKind.fireAlarm,
  'Smoke detector, smoke alarm': SoundKind.fireAlarm,
  'Siren': SoundKind.siren,
  'Civil defense siren': SoundKind.siren,
  'Vehicle horn, car horn, honking': SoundKind.horn,
  'Air horn, truck horn': SoundKind.horn,
  'Telephone bell ringing': SoundKind.phone,
  'Ringtone': SoundKind.phone,
  'Doorbell': SoundKind.door,
  'Ding-dong': SoundKind.door,
  'Knock': SoundKind.door,
};

/// Labels of the trained detector (tools/train_danger_sounds.py) as alert kinds.
const dangerLabels = <String, SoundKind>{
  'fire_alarm': SoundKind.fireAlarm,
  'siren': SoundKind.siren,
  'horn': SoundKind.horn,
  'glass_break': SoundKind.glassBreak,
};

/// Echo's own detector for dangerous sounds: softmax(W · e + b) over the normalised YAMNet
/// embedding, trained on ESC-50, speech and synthetic fire alarms (assets/models/danger_head.json).
class DangerHead {
  DangerHead._(this._kinds, this._weights, this._bias, this._thresholds);

  factory DangerHead.fromJson(Map<String, dynamic> json) {
    final labels = [for (final l in json['labels'] as List) l as String];
    final thresholds = (json['thresholds'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as num).toDouble()));
    return DangerHead._(
      [for (final l in labels) dangerLabels[l]],
      [for (final row in json['weights'] as List) Float32List.fromList([for (final v in row as List) (v as num).toDouble()])],
      [for (final v in json['bias'] as List) (v as num).toDouble()],
      {for (final l in labels) ?dangerLabels[l]: thresholds[l] ?? 1.0},
    );
  }

  final List<SoundKind?> _kinds;
  final List<Float32List> _weights;
  final List<double> _bias;
  final Map<SoundKind, double> _thresholds;

  double threshold(SoundKind kind) => _thresholds[kind] ?? 1.0;

  /// Probability per alert kind for one normalised embedding.
  Map<SoundKind, double> predict(List<double> embedding) {
    final logits = [
      for (var c = 0; c < _weights.length; c++) _bias[c] + similarity(_weights[c], embedding),
    ];
    final top = logits.reduce(math.max);
    final exps = [for (final l in logits) math.exp(l - top)];
    final sum = exps.reduce((a, b) => a + b);
    return {for (var c = 0; c < _kinds.length; c++) ?_kinds[c]: exps[c] / sum};
  }
}

/// One window through YAMNet: 521 class scores and the 1024-value embedding.
class YamnetOutput {
  const YamnetOutput(this.scores, this.embedding);
  final List<double> scores;
  final Float32List embedding;
}

/// Turns a PCM16 little-endian byte stream into overlapping windows in [-1, 1].
class PcmWindower {
  PcmWindower({this.window = yamnetWindow, this.hop = yamnetHop});

  final int window;
  final int hop;
  final _samples = <double>[];
  int? _pendingByte;

  List<Float32List> add(Uint8List bytes) {
    var start = 0;
    if (_pendingByte != null && bytes.isNotEmpty) {
      _addSample(_pendingByte! | (bytes[0] << 8));
      _pendingByte = null;
      start = 1;
    }
    for (var i = start; i + 1 < bytes.length; i += 2) {
      _addSample(bytes[i] | (bytes[i + 1] << 8));
    }
    if ((bytes.length - start).isOdd) _pendingByte = bytes.last;

    final windows = <Float32List>[];
    while (_samples.length >= window) {
      windows.add(Float32List.fromList(_samples.sublist(0, window)));
      _samples.removeRange(0, hop);
    }
    return windows;
  }

  void reset() {
    _samples.clear();
    _pendingByte = null;
  }

  void _addSample(int unsigned) {
    final signed = unsigned >= 0x8000 ? unsigned - 0x10000 : unsigned;
    _samples.add(signed / 32768);
  }
}

/// The `display_name` column of yamnet_class_map.csv, by class index.
List<String> parseClassMap(String csv) {
  final names = <String>[];
  for (final line in csv.split('\n').skip(1)) {
    final row = line.trim();
    if (row.isEmpty) continue;
    // index,mid,display_name: the name is everything after the second comma, maybe quoted.
    final name = row.substring(row.indexOf(',', row.indexOf(',') + 1) + 1);
    names.add(name.startsWith('"') && name.endsWith('"') ? name.substring(1, name.length - 1) : name);
  }
  return names;
}

Map<int, SoundKind> mapYamnetClasses(List<String> names) => {
      for (var i = 0; i < names.length; i++) i: ?yamnetClasses[names[i]],
    };

/// Best score per kind across its YAMNet classes.
Map<SoundKind, double> kindScores(List<double> scores, Map<int, SoundKind> classes) {
  final best = <SoundKind, double>{};
  classes.forEach((index, kind) {
    if (index < scores.length) best[kind] = math.max(best[kind] ?? 0, scores[index]);
  });
  return best;
}

/// Fires a key once it is heard in [consecutive] windows in a row, then not again for [cooldown].
class DetectionGate<K> {
  DetectionGate({this.consecutive = 2, this.cooldown = const Duration(seconds: 10)});

  final int consecutive;
  final Duration cooldown;
  final _streak = <K, int>{};
  final _lastFired = <K, DateTime>{};

  List<K> update(Set<K> heard, DateTime now) {
    _streak.removeWhere((key, _) => !heard.contains(key));
    final fire = <K>[];
    for (final key in heard) {
      final streak = _streak[key] = (_streak[key] ?? 0) + 1;
      final last = _lastFired[key];
      if (streak >= consecutive && (last == null || now.difference(last) > cooldown)) {
        _lastFired[key] = now;
        fire.add(key);
      }
    }
    return fire;
  }

  void reset() => _streak.clear();
}

/// Decides which alerts a stream of YAMNet windows produces. Pure, so it is tested without the model.
class SoundAnalyzer {
  SoundAnalyzer({required this.classes, required this.locationSounds, this.head});

  final Map<int, SoundKind> classes;
  final List<LocationSound> Function() locationSounds;

  /// Our trained detector; a kind is heard when either it or the YAMNet class names say so.
  final DangerHead? head;
  final _gate = DetectionGate<Object>();

  List<SoundAlert> analyze(YamnetOutput window, DateTime now) {
    final named = kindScores(window.scores, classes);
    final learned = locationSounds();
    final embedding = normalized(window.embedding);
    final trained = head?.predict(embedding) ?? const {};
    final similarities = {for (final sound in learned) sound.id: similarity(embedding, sound.print)};

    final best = {
      for (final kind in {...named.keys, ...trained.keys}) kind: math.max(named[kind] ?? 0, trained[kind] ?? 0),
    };
    final heard = <Object>{
      for (final entry in named.entries)
        if (entry.value >= kindThreshold) entry.key,
      for (final entry in trained.entries)
        if (entry.value >= head!.threshold(entry.key)) entry.key,
      for (final entry in similarities.entries)
        if (entry.value >= locationThreshold) entry.key,
    };

    return [
      for (final key in _gate.update(heard, now))
        if (key is SoundKind)
          SoundAlert(key, at: now, confidence: best[key]!)
        else
          for (final sound in learned)
            if (sound.id == key)
              SoundAlert(SoundKind.location, at: now, confidence: similarities[key]!, label: sound.label, level: sound.level),
    ];
  }

  void reset() => _gate.reset();
}

Float32List normalized(List<double> values) {
  var sum = 0.0;
  for (final v in values) {
    sum += v * v;
  }
  final norm = math.sqrt(sum);
  return Float32List.fromList([for (final v in values) norm == 0 ? 0 : v / norm]);
}

/// Cosine similarity of two normalised vectors.
double similarity(List<double> a, List<double> b) {
  if (a.length != b.length) return 0;
  var dot = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
  }
  return dot;
}

/// What a learned sound is remembered by: the normalised mean of its samples' embeddings.
Float32List fingerprint(List<List<double>> embeddings) {
  final mean = List<double>.filled(embeddings.first.length, 0);
  for (final e in embeddings) {
    final n = normalized(e);
    for (var i = 0; i < mean.length; i++) {
      mean[i] += n[i];
    }
  }
  return normalized(mean);
}
