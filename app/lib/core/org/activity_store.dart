import 'package:supabase_flutter/supabase_flutter.dart';

import '../history/meeting_store.dart';
import '../protocol.dart';
import '../server_api.dart';
import 'org_store.dart';

/// What a row of the activity log is about (supabase/migrations/…_activity_log.sql).
enum ActivityEvent {
  colleagueAlarmRaised('colleague_alarm_raised'),
  colleagueAlarmCancelled('colleague_alarm_cancelled'),
  orgAlarmReported('org_alarm_reported'),
  orgAlarmAnswered('org_alarm_answered'),
  orgAlarmClosed('org_alarm_closed'),
  meetingStarted('meeting_started'),
  meetingEnded('meeting_ended'),
  meetingDeleted('meeting_deleted'),
  meetingReadByAdmin('meeting_read_by_admin');

  const ActivityEvent(this.db);
  final String db;

  /// Null for an event this version of the app does not know yet.
  static ActivityEvent? fromDb(String value) {
    for (final event in values) {
      if (event.db == value) return event;
    }
    return null;
  }
}

/// One row of someone's history. Fixed columns only; the IP never reaches the app.
class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.at,
    required this.event,
    this.actorId,
    this.actorEmail,
    this.subjectUserId,
    this.subjectEmail,
    this.ref,
    this.title,
    this.alarmKind,
    this.status,
    this.lat,
    this.lon,
    this.accuracyM,
  });

  final int id;
  final DateTime at;
  final ActivityEvent event;

  /// Who did it; the id is gone once their account is deleted, the email stays on alarm rows.
  final String? actorId;
  final String? actorEmail;

  /// Whose meeting an admin read.
  final String? subjectUserId;
  final String? subjectEmail;

  /// The alarm, alarm event or meeting the row is about.
  final String? ref;
  final String? title;

  /// An [AlarmKind] wire name for colleague alarms, a [SoundKind] name for company alarms.
  final String? alarmKind;
  final AlarmAnswerStatus? status;
  final double? lat;
  final double? lon;
  final double? accuracyM;

  /// Null for an unknown event.
  static ActivityEntry? fromRow(Map<String, dynamic> row) {
    final event = ActivityEvent.fromDb(row['event'] as String);
    if (event == null) return null;
    final status = row['status'] as String?;
    return ActivityEntry(
      id: (row['id'] as num).toInt(),
      at: DateTime.parse(row['at'] as String).toLocal(),
      event: event,
      actorId: row['actor_id'] as String?,
      actorEmail: row['actor_email'] as String?,
      subjectUserId: row['subject_user_id'] as String?,
      subjectEmail: row['subject_email'] as String?,
      ref: row['ref'] as String?,
      title: row['title'] as String?,
      alarmKind: row['alarm_kind'] as String?,
      status: status == null ? null : AlarmAnswerStatus.fromDb(status),
      lat: (row['lat'] as num?)?.toDouble(),
      lon: (row['lon'] as num?)?.toDouble(),
      accuracyM: (row['accuracy_m'] as num?)?.toDouble(),
    );
  }
}

/// One page of history. [rawCount] and [lastId] count every row the database sent,
/// including events this version of the app skips, so paging never stops early.
class ActivityPage {
  const ActivityPage({required this.entries, required this.rawCount, this.lastId});

  final List<ActivityEntry> entries;
  final int rawCount;

  /// The oldest row's id, for the next page's `before_id`; null for an empty page.
  final int? lastId;

  static ActivityPage fromRows(List<dynamic> rows) {
    final maps = rows.cast<Map<String, dynamic>>();
    return ActivityPage(
      entries: [for (final row in maps) ?ActivityEntry.fromRow(row)],
      rawCount: maps.length,
      lastId: maps.isEmpty ? null : (maps.last['id'] as num).toInt(),
    );
  }
}

/// A meeting an employee saved for the company, as its admins list it.
class CompanyMeeting {
  const CompanyMeeting({required this.meeting, required this.ownerId, this.ownerEmail});
  final SavedMeeting meeting;
  final String ownerId;
  final String? ownerEmail;
}

/// A company meeting opened by an admin: transcript, summary and tasks.
class CompanyMeetingContent {
  const CompanyMeetingContent({
    required this.meeting,
    required this.lang,
    this.ownerEmail,
    required this.lines,
    this.summary,
  });

  final SavedMeeting meeting;
  final String lang;
  final String? ownerEmail;
  final List<SavedLine> lines;
  final MeetingSummary? summary;
}

/// The activity log and the company meetings, read only through the database's
/// functions: they never return the IP, and reading a company meeting writes
/// "admin X read your meeting" into the employee's history.
abstract class ActivityStore {
  /// The signed-in user's history, newest first; [beforeId] continues an earlier page.
  Future<ActivityPage> myActivity({int? beforeId, int maxRows = 50});

  /// A company's history, newest first. Empty for anyone but its admins.
  Future<ActivityPage> companyActivity(String orgId, {int? beforeId, int maxRows = 50});

  /// Meetings saved for the company, newest first. Empty for anyone but its admins.
  Future<List<CompanyMeeting>> companyMeetings(String orgId);

  /// Opens one company meeting. Call it only when the admin actually opens it:
  /// the reading goes into the employee's history.
  Future<CompanyMeetingContent> companyMeeting(String meetingId);
}

class SupabaseActivityStore implements ActivityStore {
  SupabaseActivityStore(this._client);

  final SupabaseClient _client;

  @override
  Future<ActivityPage> myActivity({int? beforeId, int maxRows = 50}) async =>
      _page(await _client.rpc('my_activity', params: {'before_id': beforeId, 'max_rows': maxRows}));

  @override
  Future<ActivityPage> companyActivity(String orgId, {int? beforeId, int maxRows = 50}) async => _page(
        await _client.rpc('company_activity', params: {'target_org': orgId, 'before_id': beforeId, 'max_rows': maxRows}),
      );

  @override
  Future<List<CompanyMeeting>> companyMeetings(String orgId) async {
    final rows = await _client.rpc('company_meetings', params: {'target_org': orgId}) as List<dynamic>;
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        CompanyMeeting(
          meeting: _meeting(row),
          ownerId: row['owner_id'] as String,
          ownerEmail: row['owner_email'] as String?,
        ),
    ];
  }

  @override
  Future<CompanyMeetingContent> companyMeeting(String meetingId) async {
    final json = await _client.rpc('company_meeting', params: {'meeting': meetingId}) as Map<String, dynamic>;
    final summary = json['summary'] as String?;
    final lang = json['lang'] as String? ?? '';
    return CompanyMeetingContent(
      meeting: _meeting(json),
      lang: lang,
      ownerEmail: json['owner_email'] as String?,
      lines: [
        for (final line in (json['lines'] as List).cast<Map<String, dynamic>>())
          SavedLine(
            seq: line['seq'] as int,
            captionId: 'line-${line['seq']}',
            speaker: Speaker.values.byName(line['speaker'] as String),
            text: line['text'] as String,
            spokenAt: DateTime.parse(line['spoken_at'] as String).toLocal(),
          ),
      ],
      summary: summary == null
          ? null
          : MeetingSummary(
              summary: summary,
              tasks: [
                for (final task in ((json['tasks'] as List?) ?? const []).cast<Map<String, dynamic>>())
                  MeetingTask(text: task['text'] as String, owner: task['owner'] as String?),
              ],
            ),
    );
  }

  static ActivityPage _page(dynamic rows) => ActivityPage.fromRows(rows as List<dynamic>);

  static SavedMeeting _meeting(Map<String, dynamic> row) => SavedMeeting(
        id: row['id'] as String,
        title: row['title'] as String?,
        startedAt: DateTime.parse(row['started_at'] as String).toLocal(),
        endedAt: row['ended_at'] == null ? null : DateTime.parse(row['ended_at'] as String).toLocal(),
      );
}
