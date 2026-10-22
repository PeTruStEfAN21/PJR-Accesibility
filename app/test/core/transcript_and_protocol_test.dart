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
