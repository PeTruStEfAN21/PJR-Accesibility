import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/protocol.dart';
import 'package:pjr_accesibilitate/core/server_api.dart';
import 'package:pjr_accesibilitate/core/transcript.dart';
import 'package:pjr_accesibilitate/features/participant/my_question.dart';

Caption line(String id, String text, {Speaker speaker = Speaker.coordinator, bool isFinal = true}) =>
    Caption(id: id, speaker: speaker, text: text, isFinal: isFinal, lang: 'ro-RO', ts: 1);

const notYet = AnswerCheck(answered: false, answer: '', lineIds: []);
const friday = AnswerCheck(answered: true, answer: 'Vineri.', lineIds: [3]);

/// A checker that records each call and replies with [reply] after [delay].
class FakeChecker {
  FakeChecker({this.reply = notYet, this.delay = Duration.zero, this.error});

  AnswerCheck reply;
  Duration delay;
  Object? error;
  final calls = <(String, List<TranscriptLine>)>[];

  Future<AnswerCheck> call(String question, List<TranscriptLine> lines) async {
    calls.add((question, lines));
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (error != null) throw error!;
    return reply;
  }
}

void main() {
  late Transcript transcript;
  late FakeChecker checker;
  late MyQuestion question;

  void start([FakeChecker? custom]) {
    transcript = Transcript()
      ..upsert(line('a', 'Bun venit'))
      ..upsert(line('b', 'Avem trei puncte'));
    checker = custom ?? FakeChecker();
    question = MyQuestion(transcript: transcript, check: checker.call);
  }

  test('only lines after the question are checked, after the speaker pauses', () {
    fakeAsync((async) {
      start();
      question.asked('q1', 'Când e termenul?');
      question.markRead('q1');
      transcript.upsert(line('c', 'Termenul e vineri'));

      async.elapse(const Duration(milliseconds: 2900));
      expect(checker.calls, isEmpty);
      async.elapse(const Duration(milliseconds: 200));

      expect(checker.calls.single.$1, 'Când e termenul?');
      expect(checker.calls.single.$2.map((l) => l.toJson()), [
        {'id': 3, 'speaker': 'coordinator', 'text': 'Termenul e vineri'},
      ]);
      expect(question.state, MyQuestionState.read);
    });
  });

  test('waits until three seconds pass without a new line', () {
    fakeAsync((async) {
      start();
      question
        ..asked('q1', 'Când?')
        ..markRead('q1');
      transcript.upsert(line('c', 'Termenul'));
      async.elapse(const Duration(seconds: 2));
      transcript.upsert(line('d', 'e vineri'));
      async.elapse(const Duration(milliseconds: 2900));
      expect(checker.calls, isEmpty);
      async.elapse(const Duration(milliseconds: 200));
      expect(checker.calls.single.$2, hasLength(2));
    });
  });

  test('partial captions do not count as new lines', () {
    fakeAsync((async) {
      start();
      question
        ..asked('q1', 'Când?')
        ..markRead('q1');
      transcript.upsert(line('c', 'Termenul e', isFinal: false));
      async.elapse(const Duration(seconds: 10));
      expect(checker.calls, isEmpty);
    });
  });

  test('one call at a time; after "not yet" the next line checks again', () {
    fakeAsync((async) {
      start(FakeChecker(delay: const Duration(seconds: 10)));
      question
        ..asked('q1', 'Când?')
        ..markRead('q1');
      transcript.upsert(line('c', 'unu'));
      async.elapse(const Duration(seconds: 4)); // call started at 3 s, answers at 13 s
      transcript.upsert(line('d', 'doi'));
      async.elapse(const Duration(seconds: 4));
      transcript.upsert(line('e', 'trei'));
      async.elapse(const Duration(seconds: 6)); // 14 s
      expect(checker.calls, hasLength(1));

      transcript.upsert(line('f', 'patru'));
      async.elapse(const Duration(seconds: 3));
      expect(checker.calls, hasLength(2));
      expect(checker.calls.last.$2.map((l) => l.text), ['unu', 'doi', 'trei', 'patru']);
    });
  });

  test('an answer stops the checking and keeps the result', () {
    fakeAsync((async) {
      start(FakeChecker(reply: friday));
      question
        ..asked('q1', 'Când e termenul?')
        ..markRead('q1');
      transcript.upsert(line('c', 'Termenul e vineri'));
      async.elapse(const Duration(seconds: 3));

      expect(question.state, MyQuestionState.answered);
      expect(question.result!.answer, 'Vineri.');
      expect(question.result!.lineIds, [3]);

      transcript.upsert(line('d', 'Mai departe'));
      async.elapse(const Duration(seconds: 10));
      expect(checker.calls, hasLength(1));
    });
  });

  test('gives up after five minutes; retry checks right away and waits five more', () {
    fakeAsync((async) {
      start();
      question
        ..asked('q1', 'Când?')
        ..markRead('q1');
      transcript.upsert(line('c', 'altceva'));
      async.elapse(const Duration(minutes: 5));
      expect(question.state, MyQuestionState.notFound);
      expect(checker.calls, hasLength(1));

      question.retry();
      async.elapse(Duration.zero);
      expect(question.state, MyQuestionState.read);
      expect(checker.calls, hasLength(2));

      async.elapse(const Duration(minutes: 5));
      expect(question.state, MyQuestionState.notFound);
    });
  });

  test('retry works when the read message never arrived', () {
    fakeAsync((async) {
      start();
      question.asked('q1', 'Când?');
      transcript.upsert(line('c', 'Termenul e vineri'));
      async.elapse(const Duration(seconds: 10));
      expect(checker.calls, isEmpty);

      question.retry();
      async.elapse(Duration.zero);
      expect(checker.calls.single.$2.map((l) => l.text), ['Termenul e vineri']);
    });
  });

  test('a new question replaces the old one and stops its checking', () {
    fakeAsync((async) {
      start();
      question
        ..asked('q1', 'Când?')
        ..markRead('q1');
      transcript.upsert(line('c', 'Termenul'));
      async.elapse(const Duration(seconds: 1));

      question.asked('q2', 'Unde?');
      expect(question.id, 'q2');
      expect(question.text, 'Unde?');
      expect(question.state, MyQuestionState.sent);
      async.elapse(const Duration(seconds: 10));
      expect(checker.calls, isEmpty);
    });
  });

  test('a server error stops the checking quietly until retry', () {
    fakeAsync((async) {
      start(FakeChecker(error: ApiException(503, 'AI not configured')));
      question
        ..asked('q1', 'Când?')
        ..markRead('q1');
      transcript.upsert(line('c', 'unu'));
      async.elapse(const Duration(seconds: 3));
      expect(question.state, MyQuestionState.read);

      transcript.upsert(line('d', 'doi'));
      async.elapse(const Duration(seconds: 10));
      expect(checker.calls, hasLength(1));

      question.retry();
      async.elapse(Duration.zero);
      expect(checker.calls, hasLength(2));
    });
  });

  test('read for another question is ignored', () {
    start();
    question
      ..asked('q1', 'Când?')
      ..markRead('other');
    expect(question.state, MyQuestionState.sent);
  });

  test('dismiss clears the question', () {
    start(FakeChecker(reply: friday));
    question
      ..asked('q1', 'Când?')
      ..dismiss();
    expect(question.id, isNull);
    expect(question.state, isNull);
  });
}
