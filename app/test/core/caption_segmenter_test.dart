import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/speech/caption_segmenter.dart';

void main() {
  late int counter;
  late CaptionSegmenter segmenter;

  setUp(() {
    counter = 0;
    segmenter = CaptionSegmenter(maxWords: 5, idGenerator: () => 'id${++counter}');
  });

  test('partial updates keep the same caption id', () {
    final a = segmenter.onWords('bună');
    final b = segmenter.onWords('bună ziua');
    expect(a!.id, b!.id);
    expect(b.text, 'bună ziua');
    expect(b.isFinal, isFalse);
  });

  test('commit closes the caption and the next words start a new one (Chrome style)', () {
    segmenter.onWords('bună ziua');
    final closed = segmenter.commit()!;
    expect(closed.isFinal, isTrue);
    expect(closed.text, 'bună ziua');

    final next = segmenter.onWords('bună ziua tuturor celor');
    expect(next!.id, isNot(closed.id));
    expect(next.text, 'tuturor celor');
  });

  test('nothing new after a commit yields no caption', () {
    segmenter.onWords('salut');
    segmenter.commit();
    expect(segmenter.onWords('salut'), isNull);
    expect(segmenter.commit(), isNull);
  });

  test('a long caption is closed after maxWords', () {
    final segment = segmenter.onWords('unu doi trei patru cinci');
    expect(segment!.isFinal, isTrue);
    expect(segmenter.onWords('unu doi trei patru cinci șase')!.text, 'șase');
  });

  test('a new session starts from empty text (iOS style)', () {
    segmenter.onWords('prima frază');
    final closed = segmenter.endSession()!;
    expect(closed.text, 'prima frază');
    expect(segmenter.onWords('a doua')!.text, 'a doua');
  });
}
