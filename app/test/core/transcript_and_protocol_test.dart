import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/join_link.dart';
import 'package:pjr_accesibilitate/core/protocol.dart';
import 'package:pjr_accesibilitate/core/transcript.dart';

Caption caption(String id, String text, {bool isFinal = true, Speaker speaker = Speaker.coordinator}) =>
    Caption(id: id, speaker: speaker, text: text, isFinal: isFinal, lang: 'ro-RO', ts: 1);

void main() {
  group('Transcript', () {
    test('partial captions are replaced in place by their final version', () {
      final transcript = Transcript()
        ..upsert(caption('a', 'bună', isFinal: false))
        ..upsert(caption('b', 'întrebare', speaker: Speaker.public))
        ..upsert(caption('a', 'bună ziua'));
      expect(transcript.captions.map((c) => c.text), ['bună ziua', 'întrebare']);
    });

    test('final lines are numbered from 1 and skip partial captions', () {
      final transcript = Transcript()
        ..upsert(caption('a', 'unu'))
        ..upsert(caption('b', 'în lucru', isFinal: false))
        ..upsert(caption('c', 'doi', speaker: Speaker.public));
      final lines = transcript.finalLines();
      expect(lines.map((l) => l.toJson()), [
        {'id': 1, 'speaker': 'coordinator', 'text': 'unu'},
        {'id': 2, 'speaker': 'public', 'text': 'doi'},
      ]);
      expect(transcript.finalNumbers(), {'a': 1, 'c': 2});
    });

    test('a partial that turns final late takes the next number and later lines keep theirs', () {
      final transcript = Transcript()
        ..upsert(caption('a', 'în lucru', isFinal: false))
        ..upsert(caption('b', 'unu'))
        ..upsert(caption('c', 'doi'))
        ..upsert(caption('a', 'gata'));
      expect(transcript.finalNumbers(), {'a': 3, 'b': 1, 'c': 2});
      expect(transcript.finalLines().map((l) => (l.number, l.text)), [(3, 'gata'), (1, 'unu'), (2, 'doi')]);
      expect(transcript.lastNumber, 3);
    });

    test('removing a final caption does not renumber the others and its number is not reused', () {
      final transcript = Transcript()
        ..upsert(caption('a', 'unu'))
        ..upsert(caption('b', 'doi'))
        ..upsert(caption('c', 'trei'))
        ..remove('a')
        ..upsert(caption('d', 'patru'));
      expect(transcript.finalNumbers(), {'b': 2, 'c': 3, 'd': 4});
      expect(transcript.finalLines().map((l) => l.number), [2, 3, 4]);
    });

    test('clear starts the numbering again from 1', () {
      final transcript = Transcript()
        ..upsert(caption('a', 'unu'))
        ..clear()
        ..upsert(caption('b', 'doi'));
      expect(transcript.finalNumbers(), {'b': 1});
      expect(transcript.lastNumber, 1);
    });

    test('blank captions are ignored and remove drops a caption', () {
      final transcript = Transcript()
        ..upsert(caption('a', '   '))
        ..upsert(caption('b', 'text'))
        ..remove('b');
      expect(transcript.isEmpty, isTrue);
    });

    test('latest finds the newest caption of a speaker', () {
      final transcript = Transcript()
        ..upsert(caption('a', 'vechi'))
        ..upsert(caption('b', 'public', speaker: Speaker.public))
        ..upsert(caption('c', 'nou'));
      expect(transcript.latest(Speaker.coordinator)!.text, 'nou');
    });
  });

  group('protocol', () {
    test('caption round-trips through JSON', () {
      final json = caption('a', 'salut').toJson();
      final event = ServerEvent.fromJson(json);
      expect(event, isA<CaptionReceived>());
      expect((event as CaptionReceived).caption.toJson(), json);
    });

    test('unknown or malformed messages are ignored', () {
      expect(ServerEvent.fromJson({'type': 'future-feature'}), isNull);
      expect(ServerEvent.fromJson({'type': 'caption', 'id': 1}), isNull);
    });

    test('read message round-trips and says who read the question', () {
      expect(const ReadMessage(id: 'q1', by: ReadBy.speaker).toJson(), {'type': 'read', 'id': 'q1', 'by': 'speaker'});
      final event = ServerEvent.fromJson({'type': 'read', 'id': 'q1', 'by': 'voice'});
      expect(event, isA<ReadReceived>());
      expect((event as ReadReceived).id, 'q1');
      expect(event.by, ReadBy.voice);
      expect(ServerEvent.fromJson({'type': 'read', 'id': 'q1', 'by': 'robot'}), isNull);
    });

    test('speaking messages round-trip', () {
      expect(const SpeakingMessage(id: 's1', active: true, ts: 5).toJson(), {'type': 'speaking', 'id': 's1', 'active': true, 'ts': 5});
      final event = ServerEvent.fromJson({'type': 'speaking', 'id': 's1', 'active': false, 'ts': 5});
      expect(event, isA<SpeakingReceived>());
      expect((event as SpeakingReceived).id, 's1');
      expect(event.active, isFalse);
    });

    test('hand notify carries no text', () {
      final event = ServerEvent.fromJson({'type': 'notify', 'id': 'h1', 'kind': 'hand', 'text': '', 'ts': 1});
      expect((event as NotifyReceived).notify.kind, NotifyKind.hand);
      expect(event.notify.text, '');
    });

    test('joined carries the connected peers', () {
      final event = ServerEvent.fromJson({'type': 'joined', 'code': 'ABC234', 'role': 'presenter', 'peers': {'presenter': 1}});
      expect((event as Joined).peers, {'presenter': 1});
    });
  });

  group('JoinLink', () {
    test('parses the QR link and builds the socket address', () {
      final link = JoinLink.parse('http://172.20.10.2:8000/?code=abc234')!;
      expect(link.code, 'ABC234');
      expect(link.server.toString(), 'http://172.20.10.2:8000');
      expect(link.socketUri('participant').toString(), 'ws://172.20.10.2:8000/ws/ABC234?role=participant');
      expect(JoinLink.parse(link.toUri().toString())!.code, 'ABC234');
    });

    test('https servers use wss', () {
      final link = JoinLink.parse('https://demo.example/?code=ABC234')!;
      expect(link.socketUri('presenter').scheme, 'wss');
    });

    test('rejects links that are not meetings', () {
      expect(JoinLink.parse('https://example.com'), isNull);
      expect(JoinLink.parse('http://x/?code=ABC10I'), isNull); // 0, 1 and I are not in the alphabet
      expect(JoinLink.parse('ftp://x/?code=ABC234'), isNull);
      expect(JoinLink.parse('not a url'), isNull);
    });
  });
}
