import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/protocol.dart';
import 'package:pjr_accesibilitate/features/presenter/test_meeting.dart';
import 'package:pjr_accesibilitate/features/presenter/test_meeting_review.dart';
import 'package:pjr_accesibilitate/l10n/app_localizations.dart';

int u16(Uint8List b, int at) => ByteData.sublistView(b).getUint16(at, Endian.little);
int u32(Uint8List b, int at) => ByteData.sublistView(b).getUint32(at, Endian.little);

/// Reads the local file entries of a stored (uncompressed) zip: name -> (crc, data).
Map<String, (int, Uint8List)> readZip(Uint8List zip) {
  final entries = <String, (int, Uint8List)>{};
  var at = 0;
  while (u32(zip, at) == 0x04034b50) {
    expect(u16(zip, at + 8), 0, reason: 'stored, no compression');
    final crc = u32(zip, at + 14);
    final size = u32(zip, at + 18);
    final nameLength = u16(zip, at + 26);
    final extraLength = u16(zip, at + 28);
    final name = utf8.decode(zip.sublist(at + 30, at + 30 + nameLength));
    final start = at + 30 + nameLength + extraLength;
    entries[name] = (crc, zip.sublist(start, start + size));
    at = start + size;
  }
  expect(u32(zip, at), 0x02014b50, reason: 'central directory follows the files');
  return entries;
}

Float32List clip(double seconds) => Float32List((seconds * 16000).round());

void main() {
  test('crc32 matches the standard check value', () {
    expect(crc32(utf8.encode('123456789')), 0xCBF43926);
  });

  test('encodeWav writes a 16-bit mono PCM file and clips out-of-range samples', () {
    final wav = encodeWav(Float32List.fromList([1.0, -1.0, 2.0, 0.0]));

    expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
    expect(u32(wav, 4), wav.length - 8);
    expect(ascii.decode(wav.sublist(8, 16)), 'WAVEfmt ');
    expect(u16(wav, 20), 1); // PCM
    expect(u16(wav, 22), 1); // mono
    expect(u32(wav, 24), 16000);
    expect(u16(wav, 34), 16);
    expect(ascii.decode(wav.sublist(36, 40)), 'data');
    expect(u32(wav, 40), 8);
    final samples = ByteData.sublistView(wav, 44);
    expect([for (var i = 0; i < 4; i++) samples.getInt16(i * 2, Endian.little)], [32767, -32768, 32767, 0]);
  });

  test('the archive holds the enrollment, every clip and the labels the team set', () {
    final recorder = TestMeetingRecorder(model: 'redimnet2-b6-vb2+vox2_v0-lm')
      ..setEnrollment(clip(20))
      ..add(id: 'c1', text: 'Bun venit', predicted: Speaker.coordinator, score: 0.81, clip: clip(2), reason: 'judged')
      ..add(id: 'c2', text: 'Când e termenul', predicted: Speaker.coordinator, score: 0.52, clip: clip(1.5), reason: 'judged')
      ..setLabel('c2', Speaker.public);

    final entries = readZip(recorder.buildArchive());

    expect(entries.keys, ['enrollment.wav', 'clips/001.wav', 'clips/002.wav', 'labels.json']);
    for (final (crc, data) in entries.values) {
      expect(crc, crc32(data));
    }
    expect(entries['clips/002.wav']!.$2.length, 44 + 2 * 24000);
    final labels = jsonDecode(utf8.decode(entries['labels.json']!.$2)) as Map<String, dynamic>;
    expect(labels['version'], 1);
    expect(labels['sample_rate'], 16000);
    expect(labels['model'], 'redimnet2-b6-vb2+vox2_v0-lm');
    expect(labels['enrollment'], 'enrollment.wav');
    expect(labels['lines'], [
      {'id': 'c1', 'file': 'clips/001.wav', 'text': 'Bun venit', 'predicted': 'coordinator', 'score': 0.81, 'reason': 'judged', 'label': 'coordinator'},
      {'id': 'c2', 'file': 'clips/002.wav', 'text': 'Când e termenul', 'predicted': 'coordinator', 'score': 0.52, 'reason': 'judged', 'label': 'public'},
    ]);
  });

  testWidgets('the review screen lets the team fix labels, listen and download', (tester) async {
    final recorder = TestMeetingRecorder(model: 'm')
      ..setEnrollment(clip(20))
      ..add(id: 'c1', text: 'Bun venit', predicted: Speaker.coordinator, score: 0.81, clip: clip(2));
    final played = <int>[];
    final downloads = <(String, int)>[];
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ro'),
      home: TestMeetingReview(
        recorder: recorder,
        play: (samples) async => played.add(samples.length),
        download: (bytes, name) => downloads.add((name, bytes.length)),
      ),
    ));
    expect(find.text('Bun venit'), findsOneWidget);
    await tester.tap(find.text('Din sală'));
    await tester.pump();
    expect(recorder.lines.single.label, Speaker.public);

    await tester.tap(find.text('Ascultă'));
    await tester.pump();
    expect(played, [32000]);

    await tester.tap(find.text('Descarcă'));
    await tester.pump();
    expect(downloads.single.$1, matches(RegExp(r'^echo-test-meeting-\d{8}-\d{4}\.zip$')));
    expect(downloads.single.$2, greaterThan(32000 * 2));
  });
}
