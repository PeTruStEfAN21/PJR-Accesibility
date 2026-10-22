import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/protocol.dart';
import 'package:pjr_accesibilitate/core/server_api.dart';
import 'package:pjr_accesibilitate/core/transcript.dart';
import 'package:pjr_accesibilitate/features/participant/room_questions.dart';

Caption line(String id, String text, {Speaker speaker = Speaker.public, bool isFinal = true}) =>
    Caption(id: id, speaker: speaker, text: text, isFinal: isFinal, lang: 'ro-RO', ts: 1);

/// A finder that remembers each batch and finds no questions.
List<int> record(List<List<TranscriptLine>> batches, List<TranscriptLine> lines) {
  batches.add(lines);
  return const [];
}

void main() {
  test('sends room lines in batches of at most five, a second after they arrive', () {
    fakeAsync((async) {
      final transcript = Transcript();
      final batches = <List<TranscriptLine>>[];
      RoomQuestions(transcript: transcript, find: (lines) async => record(batches, lines), lang: 'ro-RO');
      for (var i = 0; i < 7; i++) {
        transcript.upsert(line('p$i', 'replica $i'));
        async.elapse(const Duration(milliseconds: 30));
      }
      expect(batches, isEmpty);
      async.elapse(const Duration(seconds: 1));
      expect(batches.map((b) => b.length), [5, 2]);
      expect(batches.first.first.toJson(), {'id': 1, 'speaker': 'public', 'text': 'replica 0'});
    });
  });

  test('speaker lines and partial lines are not sent', () {
    fakeAsync((async) {
      final transcript = Transcript();
      final batches = <List<TranscriptLine>>[];
      RoomQuestions(transcript: transcript, find: (lines) async => record(batches, lines), lang: 'ro-RO');
      transcript
        ..upsert(line('c1', 'cum stăm cu bugetul', speaker: Speaker.coordinator))
        ..upsert(line('p1', 'când e', isFinal: false));
      async.elapse(const Duration(seconds: 2));
      expect(batches, isEmpty);
    });
  });

  test('marks the lines the server says are questions', () {
    fakeAsync((async) {
      final transcript = Transcript();
      final questions = RoomQuestions(transcript: transcript, find: (lines) async => [1], lang: 'ro-RO');
      var notified = 0;
      questions.addListener(() => notified++);
      transcript
        ..upsert(line('p1', 'când e termenul'))
        ..upsert(line('p2', 'mulțumesc'));
      async.elapse(const Duration(seconds: 1));
      expect(questions.isQuestion('p1'), isTrue);
      expect(questions.isQuestion('p2'), isFalse);
      expect(notified, greaterThan(0));
    });
  });

  test('falls back to the local rule when the server has no AI', () {
    fakeAsync((async) {
      final transcript = Transcript();
      final questions = RoomQuestions(
        transcript: transcript,
        find: (lines) async => throw ApiException(503, 'AI not configured'),
        lang: 'ro-RO',
      );
      transcript
        ..upsert(line('p1', 'când e termenul'))
        ..upsert(line('p2', 'mulțumesc'));
      async.elapse(const Duration(seconds: 1));
      expect(questions.isQuestion('p1'), isTrue);
      expect(questions.isQuestion('p2'), isFalse);
    });
  });

  test('a server that never answers falls back to the local rule after 20 s', () {
    fakeAsync((async) {
      final transcript = Transcript();
      final questions = RoomQuestions(
        transcript: transcript,
        find: (lines) => Completer<List<int>>().future,
        lang: 'ro-RO',
      );
      transcript.upsert(line('p1', 'când e termenul'));
      async.elapse(const Duration(seconds: 1 + 19));
      expect(questions.isQuestion('p1'), isFalse);
      async.elapse(const Duration(seconds: 2));
      expect(questions.isQuestion('p1'), isTrue);
    });
  });

  group('looksLikeQuestion', () {
    test('Romanian question words, with or without diacritics', () {
      expect(looksLikeQuestion('Când e termenul', 'ro-RO'), isTrue);
      expect(looksLikeQuestion('cand e termenul', 'ro-RO'), isTrue);
      expect(looksLikeQuestion('De ce am amânat', 'ro-RO'), isTrue);
      expect(looksLikeQuestion('Se poate muta ședința', 'ro-RO'), isTrue);
    });

    test('a question mark is enough', () {
      expect(looksLikeQuestion('e gata raportul?', 'ro-RO'), isTrue);
    });

    test('statements are not questions', () {
      expect(looksLikeQuestion('Mulțumesc mult', 'ro-RO'), isFalse);
      expect(looksLikeQuestion('De asemenea avem bugetul', 'ro-RO'), isFalse);
    });

    test('English question words', () {
      expect(looksLikeQuestion('what is the deadline', 'en-US'), isTrue);
      expect(looksLikeQuestion('thanks a lot', 'en-US'), isFalse);
    });
  });
}
