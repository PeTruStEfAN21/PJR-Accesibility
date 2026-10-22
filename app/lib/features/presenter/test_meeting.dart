import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../core/protocol.dart';

const _rate = 16000;

/// 16-bit mono PCM WAV; samples outside [-1, 1] are clipped.
Uint8List encodeWav(Float32List samples, {int sampleRate = _rate}) {
  final data = ByteData(44 + samples.length * 2);
  void ascii(int at, String text) {
    for (var i = 0; i < text.length; i++) {
      data.setUint8(at + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + samples.length * 2, Endian.little);
  ascii(8, 'WAVEfmt ');
  data
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, 1, Endian.little) // mono
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, sampleRate * 2, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, samples.length * 2, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final s = samples[i].clamp(-1.0, 1.0);
    data.setInt16(44 + i * 2, s < 0 ? (s * 32768).round() : (s * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

/// CRC-32 as zip files use it.
int crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

/// A zip with every file stored as is (audio does not compress much, and no package is needed).
Uint8List _storedZip(List<(String, Uint8List)> files) {
  final out = BytesBuilder();
  final central = BytesBuilder();
  ByteData header(int size) => ByteData(size);
  for (final (name, bytes) in files) {
    final nameBytes = utf8.encode(name);
    final crc = crc32(bytes);
    final offset = out.length;
    final local = header(30)
      ..setUint32(0, 0x04034b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(6, 0x0800, Endian.little) // names are UTF-8
      ..setUint32(14, crc, Endian.little)
      ..setUint32(18, bytes.length, Endian.little)
      ..setUint32(22, bytes.length, Endian.little)
      ..setUint16(26, nameBytes.length, Endian.little);
    out
      ..add(local.buffer.asUint8List())
      ..add(nameBytes)
      ..add(bytes);
    final entry = header(46)
      ..setUint32(0, 0x02014b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(6, 20, Endian.little)
      ..setUint16(8, 0x0800, Endian.little)
      ..setUint32(16, crc, Endian.little)
      ..setUint32(20, bytes.length, Endian.little)
      ..setUint32(24, bytes.length, Endian.little)
      ..setUint16(28, nameBytes.length, Endian.little)
      ..setUint32(42, offset, Endian.little);
    central
      ..add(entry.buffer.asUint8List())
      ..add(nameBytes);
  }
  final centralStart = out.length;
  final centralBytes = central.takeBytes();
  out.add(centralBytes);
  final end = header(22)
    ..setUint32(0, 0x06054b50, Endian.little)
    ..setUint16(8, files.length, Endian.little)
    ..setUint16(10, files.length, Endian.little)
    ..setUint32(12, centralBytes.length, Endian.little)
    ..setUint32(16, centralStart, Endian.little);
  out.add(end.buffer.asUint8List());
  return out.takeBytes();
}

class RecordedLine {
  RecordedLine({
    required this.id,
    required this.text,
    required this.predicted,
    required this.score,
    required this.reason,
    required this.clip,
  }) : label = predicted;

  final String id;
  final String text;

  /// What the page decided while the meeting ran.
  final Speaker predicted;
  final double? score;

  /// Why the page labelled it so (judged, tooShort, notEnrolled, forced, modelError).
  final String reason;
  final Float32List clip;

  /// What the team says it was, after listening.
  Speaker label;
}

/// A test meeting: the enrollment recording and, for each final caption, the audio the label was decided
/// on. Everything stays on the laptop until the team downloads the archive for `ml/voice`.
class TestMeetingRecorder extends ChangeNotifier {
  TestMeetingRecorder({required this.model});

  /// The voice model that labelled the lines (from voice_head.json).
  final String model;

  Float32List? _enrollment;
  final _lines = <RecordedLine>[];

  List<RecordedLine> get lines => List.unmodifiable(_lines);

  Float32List? get enrollment => _enrollment;

  void setEnrollment(Float32List samples) => _enrollment = samples;

  void add({
    required String id,
    required String text,
    required Speaker predicted,
    required double? score,
    required Float32List clip,
    String reason = 'judged',
  }) {
    _lines.add(RecordedLine(id: id, text: text, predicted: predicted, score: score, reason: reason, clip: clip));
    notifyListeners();
  }

  void setLabel(String id, Speaker label) {
    for (final line in _lines) {
      if (line.id == id) line.label = label;
    }
    notifyListeners();
  }

  Uint8List buildArchive() {
    final files = <(String, Uint8List)>[('enrollment.wav', encodeWav(_enrollment ?? Float32List(0)))];
    final described = <Map<String, Object?>>[];
    for (final (i, line) in _lines.indexed) {
      final name = 'clips/${(i + 1).toString().padLeft(3, '0')}.wav';
      files.add((name, encodeWav(line.clip)));
      described.add({
        'id': line.id,
        'file': name,
        'text': line.text,
        'predicted': line.predicted.name,
        'score': line.score,
        'reason': line.reason,
        'label': line.label.name,
      });
    }
    final labels = {'version': 1, 'sample_rate': _rate, 'model': model, 'enrollment': 'enrollment.wav', 'lines': described};
    files.add(('labels.json', Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(labels)))));
    return _storedZip(files);
  }
}
