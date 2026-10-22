import 'package:supabase_flutter/supabase_flutter.dart';

import '../protocol.dart';
import '../server_api.dart';

class SavedMeeting {
  const SavedMeeting({required this.id, this.title, required this.startedAt, this.endedAt});

  final String id;
  final String? title;
  final DateTime startedAt;
  final DateTime? endedAt;
}

/// A meeting found by search, with the first matching line when the match was in the transcript.
class MeetingMatch {
  const MeetingMatch({required this.meeting, this.seq, this.snippet});

  final SavedMeeting meeting;
  final int? seq;
  final String? snippet;
}

/// One final caption as saved. [seq] numbers the lines from 1, as cited by the AI.
class SavedLine {
  const SavedLine({
    required this.seq,
    required this.captionId,
    required this.speaker,
    required this.text,
    required this.spokenAt,
  });

  final int seq;
  final String captionId;
  final Speaker speaker;
  final String text;
  final DateTime spokenAt;

  Caption toCaption(String lang) => Caption(
        id: captionId,
        speaker: speaker,
        text: text,
        isFinal: true,
        lang: lang,
        ts: spokenAt.millisecondsSinceEpoch,
      );
}

/// The signed-in user's saved meetings (tables in supabase/migrations/).
/// Every call acts as that user: Row Level Security hides everyone else's rows.
abstract class MeetingStore {
  /// Returns the new meeting's id.
  Future<String> createMeeting({String? sessionCode, required String lang, String? title});

  /// Saves lines, skipping any already saved (same caption id), so a batch can be resent.
  Future<void> saveLines(String meetingId, List<SavedLine> lines);

  Future<void> finishMeeting(String meetingId);

  /// Newest first.
  Future<List<SavedMeeting>> listMeetings();

  Future<List<MeetingMatch>> search(String query);

  Future<List<SavedLine>> loadLines(String meetingId);

  Future<void> saveSummary(String meetingId, MeetingSummary summary, String lang);

  Future<MeetingSummary?> loadSummary(String meetingId);

  Future<void> renameMeeting(String meetingId, String title);

  Future<void> deleteMeeting(String meetingId);
}

class SupabaseMeetingStore implements MeetingStore {
  SupabaseMeetingStore(this._client);

  final SupabaseClient _client;

  static const _meetingColumns = 'id, title, started_at, ended_at';

  @override
  Future<String> createMeeting({String? sessionCode, required String lang, String? title}) async {
    final row = await _client
        .from('meetings')
        .insert({'lang': lang, 'session_code': sessionCode, 'title': title})
        .select('id')
        .single();
    return row['id'] as String;
  }

  @override
  Future<void> saveLines(String meetingId, List<SavedLine> lines) async {
    if (lines.isEmpty) return;
    await _client.from('meeting_lines').upsert(
      [
        for (final line in lines)
          {
            'meeting_id': meetingId,
            'seq': line.seq,
            'caption_id': line.captionId,
            'speaker': line.speaker.name,
            'text': line.text,
            'spoken_at': line.spokenAt.toUtc().toIso8601String(),
          },
      ],
      onConflict: 'meeting_id,caption_id',
      ignoreDuplicates: true,
    );
  }

  @override
  Future<void> finishMeeting(String meetingId) async {
    await _client
        .from('meetings')
        .update({'ended_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', meetingId);
  }

  @override
  Future<List<SavedMeeting>> listMeetings() async {
    final rows = await _client.from('meetings').select(_meetingColumns).order('started_at', ascending: false);
    return [for (final row in rows) _meeting(row)];
  }

  @override
  Future<List<MeetingMatch>> search(String query) async {
    final rows = await _client.rpc('search_meetings', params: {'query': query.trim()}) as List<dynamic>;
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        MeetingMatch(
          meeting: SavedMeeting(
            id: row['meeting_id'] as String,
            title: row['title'] as String?,
            startedAt: DateTime.parse(row['started_at'] as String).toLocal(),
          ),
          seq: row['seq'] as int?,
          snippet: row['snippet'] as String?,
        ),
    ];
  }

  @override
  Future<List<SavedLine>> loadLines(String meetingId) async {
    final rows = await _client
        .from('meeting_lines')
        .select('seq, caption_id, speaker, text, spoken_at')
        .eq('meeting_id', meetingId)
        .order('seq');
    return [
      for (final row in rows)
        SavedLine(
          seq: row['seq'] as int,
          captionId: row['caption_id'] as String,
          speaker: Speaker.values.byName(row['speaker'] as String),
          text: row['text'] as String,
          spokenAt: DateTime.parse(row['spoken_at'] as String).toLocal(),
        ),
    ];
  }

  @override
  Future<void> saveSummary(String meetingId, MeetingSummary summary, String lang) async {
    await _client.from('summaries').upsert({
      'meeting_id': meetingId,
      'summary': summary.summary,
      'tasks': [
        for (final task in summary.tasks) {'text': task.text, 'owner': task.owner},
      ],
      'lang': lang,
    });
  }

  @override
  Future<MeetingSummary?> loadSummary(String meetingId) async {
    final row = await _client.from('summaries').select('summary, tasks').eq('meeting_id', meetingId).maybeSingle();
    if (row == null) return null;
    return MeetingSummary(
      summary: row['summary'] as String,
      tasks: [
        for (final task in (row['tasks'] as List).cast<Map<String, dynamic>>())
          MeetingTask(text: task['text'] as String, owner: task['owner'] as String?),
      ],
    );
  }

  @override
  Future<void> renameMeeting(String meetingId, String title) async {
    final trimmed = title.trim();
    await _client.from('meetings').update({'title': trimmed.isEmpty ? null : trimmed}).eq('id', meetingId);
  }

  @override
  Future<void> deleteMeeting(String meetingId) async {
    await _client.from('meetings').delete().eq('id', meetingId);
  }

  static SavedMeeting _meeting(Map<String, dynamic> row) => SavedMeeting(
        id: row['id'] as String,
        title: row['title'] as String?,
        startedAt: DateTime.parse(row['started_at'] as String).toLocal(),
        endedAt: row['ended_at'] == null ? null : DateTime.parse(row['ended_at'] as String).toLocal(),
      );
}
