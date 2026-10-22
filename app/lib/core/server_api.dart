import 'dart:convert';

import 'package:http/http.dart' as http;

import 'transcript.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class MeetingTask {
  const MeetingTask({required this.text, this.owner});
  final String text;
  final String? owner;
}

class MeetingSummary {
  const MeetingSummary({required this.summary, required this.tasks});
  final String summary;
  final List<MeetingTask> tasks;
}

class MeetingAnswer {
  const MeetingAnswer({required this.answer, required this.citations});
  final String answer;
  final List<int> citations;
}

/// Whether the speaker answered the participant's question, from the lines said since it was sent.
class AnswerCheck {
  const AnswerCheck({required this.answered, required this.answer, required this.lineIds});
  final bool answered;
  final String answer;

  /// Lines the answer comes from, numbered as in [Transcript.finalLines].
  final List<int> lineIds;
}

/// HTTP calls to server/ (see the REST table in the design doc).
class ServerApi {
  ServerApi(this.baseUrl, {http.Client? client}) : _client = client ?? http.Client();

  final Uri baseUrl;
  final http.Client _client;

  Future<String> createSession() async => (await _post('/api/sessions', {}))['code'] as String;

  Future<Uri> publicUrl() async {
    final response = await _client.get(baseUrl.resolve('/api/config'));
    _check(response);
    return Uri.parse(jsonDecode(response.body)['public_url'] as String);
  }

  Future<MeetingSummary> summarize(String lang, List<TranscriptLine> lines) async {
    final json = await _post('/api/ai/summary', {'lang': lang, 'lines': [for (final l in lines) l.toJson()]});
    return MeetingSummary(
      summary: json['summary'] as String,
      tasks: [
        for (final t in json['tasks'] as List) MeetingTask(text: t['text'] as String, owner: t['owner'] as String?),
      ],
    );
  }

  Future<String> simplify(String lang, String text) async =>
      (await _post('/api/ai/simplify', {'lang': lang, 'text': text}))['text'] as String;

  Future<MeetingAnswer> ask(String lang, List<TranscriptLine> lines, String question) async {
    final json = await _post('/api/ai/ask', {
      'lang': lang,
      'question': question,
      'lines': [for (final l in lines) l.toJson()],
    });
    return MeetingAnswer(answer: json['answer'] as String, citations: List<int>.from(json['citations'] as List));
  }

  Future<AnswerCheck> checkAnswer(String lang, String question, List<TranscriptLine> lines) async {
    final json = await _post('/api/ai/answer-check', {
      'lang': lang,
      'question': question,
      'lines': [for (final l in lines) l.toJson()],
    });
    return AnswerCheck(
      answered: json['answered'] as bool,
      answer: json['answer'] as String,
      lineIds: List<int>.from(json['line_ids'] as List),
    );
  }

  Future<List<int>> findQuestions(String lang, List<TranscriptLine> lines) async {
    final json = await _post('/api/ai/questions', {'lang': lang, 'lines': [for (final l in lines) l.toJson()]});
    return List<int>.from(json['question_ids'] as List);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, Object> body) async {
    final response = await _client.post(
      baseUrl.resolve(path),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
    _check(response);
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  static void _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var message = response.reasonPhrase ?? 'error';
    try {
      message = (jsonDecode(utf8.decode(response.bodyBytes)) as Map)['detail'].toString();
    } on Object {
      // Body was not JSON; keep the reason phrase.
    }
    throw ApiException(response.statusCode, message);
  }
}
