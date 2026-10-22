import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/history/meeting_recorder.dart';
import 'package:pjr_accesibilitate/core/protocol.dart';
import 'package:pjr_accesibilitate/core/transcript.dart';

import '../fakes.dart';

Caption caption(String id, String text, {bool isFinal = true, Speaker speaker = Speaker.coordinator}) =>
    Caption(id: id, speaker: speaker, text: text, isFinal: isFinal, lang: 'ro-RO', ts: 1000);

void main() {
  late FakeMeetingStore store;
  late Transcript transcript;
  late MeetingRecorder recorder;

  setUp(() {
    store = FakeMeetingStore();
    transcript = Transcript();
    recorder = MeetingRecorder(store: store, transcript: transcript, lang: 'ro-RO', sessionCode: 'ABC234');
  });

  test('saves only final captions, numbered in the order they became final', () {
    fakeAsync((async) {
      recorder.start();
      transcript.upsert(caption('a', 'Bună', isFinal: false));
      transcript.upsert(caption('b', 'Întrebare', speaker: Speaker.public));
      transcript.upsert(caption('a', 'Bună ziua'));
      async.elapse(const Duration(seconds: 30));

      final saved = store.lines[recorder.meetingId]!;
      expect([for (final l in saved) (l.seq, l.captionId, l.text)], [(1, 'b', 'Întrebare'), (2, 'a', 'Bună ziua')]);
      expect(saved.first.speaker, Speaker.public);
    });
  });

  test('creates the meeting only once something was said', () {
    fakeAsync((async) {
      recorder.start();
      transcript.upsert(caption('a', 'parțial', isFinal: false));
      async.elapse(const Duration(seconds: 60));
      expect(store.meetings, isEmpty);

      recorder.stop();
      async.flushMicrotasks();
      expect(store.meetings, isEmpty);
      expect(store.finished, isEmpty);
    });
  });

  test('batches lines until the next flush', () {
    fakeAsync((async) {
      recorder.start();
      transcript.upsert(caption('a', 'unu'));
      transcript.upsert(caption('b', 'doi'));
      async.elapse(const Duration(seconds: 29));
      expect(store.saveCalls, 0);

      async.elapse(const Duration(seconds: 1));
      expect(store.saveCalls, 1);
      expect(store.lines[recorder.meetingId], hasLength(2));
      expect(recorder.pendingCount, 0);
    });
  });

  test('keeps lines after a failed save and sends them on the next flush', () {
    fakeAsync((async) {
      recorder.start();
      store.failSaves = true;
      transcript.upsert(caption('a', 'unu'));
      async.elapse(const Duration(seconds: 30));
      expect(recorder.pendingCount, 1);

      store.failSaves = false;
      transcript.upsert(caption('b', 'doi'));
      async.elapse(const Duration(seconds: 30));
      expect([for (final l in store.lines[recorder.meetingId]!) l.seq], [1, 2]);
      expect(recorder.pendingCount, 0);
    });
  });

  test('stop saves the rest, ends the meeting and stops listening', () {
    fakeAsync((async) {
      recorder.start();
      transcript.upsert(caption('a', 'unu'));
      recorder.stop();
      async.flushMicrotasks();

      final id = recorder.meetingId!;
      expect(store.lines[id], hasLength(1));
      expect(store.finished, {id});

      transcript.upsert(caption('b', 'după'));
      async.elapse(const Duration(seconds: 60));
      expect(store.lines[id], hasLength(1));
    });
  });
}
