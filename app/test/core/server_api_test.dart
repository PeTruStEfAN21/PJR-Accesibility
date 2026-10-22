import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pjr_accesibilitate/core/protocol.dart';
import 'package:pjr_accesibilitate/core/server_api.dart';
import 'package:pjr_accesibilitate/core/transcript.dart';

const lines = [
  TranscriptLine(number: 3, speaker: Speaker.coordinator, text: 'Termenul e vineri'),
  TranscriptLine(number: 4, speaker: Speaker.public, text: 'mulțumesc'),
];

ServerApi apiReplying(int status, Object body, List<http.Request> requests) => ServerApi(
      Uri.parse('http://server:8000'),
      client: MockClient((request) async {
        requests.add(request);
        return http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});
      }),
    );

void main() {
  test('checkAnswer posts the question and the lines since it was sent', () async {
    final requests = <http.Request>[];
    final api = apiReplying(200, {'answered': true, 'answer': 'Vineri.', 'line_ids': [3]}, requests);

    final check = await api.checkAnswer('ro', 'Când e termenul?', lines);

    expect(requests.single.url.path, '/api/ai/answer-check');
    expect(jsonDecode(requests.single.body), {
      'lang': 'ro',
      'question': 'Când e termenul?',
      'lines': [
        {'id': 3, 'speaker': 'coordinator', 'text': 'Termenul e vineri'},
        {'id': 4, 'speaker': 'public', 'text': 'mulțumesc'},
      ],
    });
    expect(check.answered, isTrue);
    expect(check.answer, 'Vineri.');
    expect(check.lineIds, [3]);
  });

  test('findQuestions returns the ids the server marked', () async {
    final requests = <http.Request>[];
    final api = apiReplying(200, {'question_ids': [4]}, requests);

    expect(await api.findQuestions('ro', lines), [4]);
    expect(requests.single.url.path, '/api/ai/questions');
  });

  test('checkAnswer throws ApiException when the server has no AI key', () async {
    final api = apiReplying(503, {'detail': 'AI not configured'}, []);
    expect(
      () => api.checkAnswer('ro', 'Când?', lines),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 503)),
    );
  });
}
