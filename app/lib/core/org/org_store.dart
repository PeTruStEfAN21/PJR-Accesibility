import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/alerts/location_sounds.dart';
import '../../features/alerts/sound_alert.dart';

enum OrgRole { admin, employee }

/// An employee's answer during an alarm.
enum AlarmAnswerStatus {
  safe('safe'),
  needHelp('need_help');

  const AlarmAnswerStatus(this.db);
  final String db;

  static AlarmAnswerStatus fromDb(String value) => values.firstWhere((s) => s.db == value);
}

/// The change would leave a company with people in it but no admin.
class LastAdminException implements Exception {
  const LastAdminException();
}

/// Turns the database's "this organization needs an admin" error (SQLSTATE EA001) into [LastAdminException].
Future<T> guardLastAdmin<T>(Future<T> call) async {
  try {
    return await call;
  } on PostgrestException catch (e) {
    if (e.code == 'EA001') throw const LastAdminException();
    rethrow;
  }
}

/// How a member takes part (supabase/migrations/…_member_experience.sql): [visual] reads what is
/// said, [standard] hears it. A need, never a diagnosis.
enum MemberExperience { standard, visual }

/// Five wrong company codes in the last hour (SQLSTATE EJ002): the database refuses for a while.
class JoinCodeTooManyAttempts implements Exception {
  const JoinCodeTooManyAttempts();
}

/// What the admin tells the whole team (…_announcements.sql). [seen]: the signed-in person marked it.
class Announcement {
  const Announcement({
    required this.id,
    required this.orgId,
    required this.orgName,
    required this.title,
    required this.body,
    required this.important,
    required this.createdAt,
    this.seen = false,
  });

  final String id;
  final String orgId;
  final String orgName;
  final String title;
  final String body;
  final bool important;
  final DateTime createdAt;
  final bool seen;
}

/// How many of the company saw an announcement, out of everyone but its author. Only the count.
typedef AnnouncementSeen = ({int seen, int audience});

/// Which YAMNet made a fingerprint: phone and browser fingerprints do not match each other.
enum SoundModel { tflite, tfjs }

class OrgMembership {
  const OrgMembership({
    required this.orgId,
    required this.orgName,
    required this.role,
    this.experience = MemberExperience.standard,
  });
  final String orgId;
  final String orgName;
  final OrgRole role;

  /// How the signed-in person takes part in this company.
  final MemberExperience experience;

  bool get isAdmin => role == OrgRole.admin;
}

/// An invitation sent to the signed-in user.
class OrgInvite {
  const OrgInvite({required this.id, required this.orgId, required this.orgName, required this.role});
  final String id;
  final String orgId;
  final String orgName;
  final OrgRole role;
}

/// An invitation the admins sent and nobody accepted yet.
class PendingInvite {
  const PendingInvite({required this.id, required this.email, required this.role, this.department});
  final String id;
  final String email;
  final OrgRole role;
  final String? department;
}

/// What an employee chooses to share with the company. Needs, never a diagnosis.
class MemberNeeds {
  const MemberNeeds({
    this.captions = true,
    this.visualAlerts = true,
    this.watchAlerts = false,
    this.largeText = false,
    this.language = 'ro',
  });

  final bool captions;
  final bool visualAlerts;
  final bool watchAlerts;
  final bool largeText;
  final String language;

  MemberNeeds copyWith({bool? captions, bool? visualAlerts, bool? watchAlerts, bool? largeText, String? language}) =>
      MemberNeeds(
        captions: captions ?? this.captions,
        visualAlerts: visualAlerts ?? this.visualAlerts,
        watchAlerts: watchAlerts ?? this.watchAlerts,
        largeText: largeText ?? this.largeText,
        language: language ?? this.language,
      );

  Map<String, Object> toRow() => {
        'captions': captions,
        'visual_alerts': visualAlerts,
        'watch_alerts': watchAlerts,
        'large_text': largeText,
        'language': language,
      };

  static MemberNeeds fromRow(Map<String, dynamic> row) => MemberNeeds(
        captions: row['captions'] as bool,
        visualAlerts: row['visual_alerts'] as bool,
        watchAlerts: row['watch_alerts'] as bool,
        largeText: row['large_text'] as bool,
        language: row['language'] as String,
      );
}

class OrgMember {
  const OrgMember({
    required this.userId,
    required this.role,
    this.email,
    this.displayName,
    this.department,
    this.needs,
    this.experience = MemberExperience.standard,
  });

  final String userId;
  final OrgRole role;
  final String? email;
  final String? displayName;
  final String? department;
  final MemberExperience experience;

  /// Null until the employee shares them.
  final MemberNeeds? needs;

  String get name => displayName ?? email ?? userId;
}

class AlarmEvent {
  const AlarmEvent({required this.id, required this.kind, required this.startedAt});
  final String id;

  /// A [SoundKind] name: "fireAlarm", "siren".
  final String kind;
  final DateTime startedAt;
}

class AlarmAnswer {
  const AlarmAnswer({required this.userId, required this.status, required this.at});
  final String userId;
  final AlarmAnswerStatus status;
  final DateTime at;
}

/// The signed-in user's organizations (supabase/migrations/…_organizations.sql).
/// Row Level Security decides what each call may see or change.
abstract class OrgStore {
  Future<List<OrgMembership>> myOrganizations();
  Future<List<OrgInvite>> myInvites();
  Future<String> createOrganization(String name);

  /// Returns the organization joined.
  Future<String> acceptInvite(String inviteId);
  Future<void> leave(String orgId, String userId);

  Future<MemberNeeds?> loadNeeds(String orgId, String userId);
  Future<void> saveNeeds(String orgId, String userId, MemberNeeds needs);

  // Admins.
  Future<List<OrgMember>> members(String orgId);
  Future<void> invite(String orgId, String email, {OrgRole role = OrgRole.employee, String? department});
  Future<List<PendingInvite>> pendingInvites(String orgId);
  Future<void> cancelInvite(String inviteId);
  Future<void> setRole(String orgId, String userId, OrgRole role);
  Future<void> removeMember(String orgId, String userId);

  /// The company code employees join with (…_company_join_codes.sql). A new one replaces the old
  /// and is shown only now: the database keeps just its fingerprint.
  Future<String> newJoinCode(String orgId);

  /// Until when the company's code works, or null without one.
  Future<DateTime?> joinCodeInfo(String orgId);
  Future<void> revokeJoinCode(String orgId);

  /// Joins the company of [code] as an employee. Returns the company, or null for a wrong or
  /// expired code; throws [JoinCodeTooManyAttempts] after too many wrong ones.
  Future<String?> joinWithCode(String code, String name, MemberExperience experience);

  /// The announcements still showing in all of the signed-in person's companies, newest first.
  Future<List<Announcement>> announcements();

  /// Admins only; it shows for [days] (1 to 90).
  Future<void> postAnnouncement(String orgId,
      {required String title, required String body, required bool important, required int days});
  Future<void> deleteAnnouncement(String announcementId);
  Future<void> markAnnouncementSeen(String announcementId);

  /// Admins only: per announcement of the company, how many saw it.
  Future<Map<String, AnnouncementSeen>> announcementSeen(String orgId);

  /// Sounds an admin learned once, for every employee's device of the same [model].
  Future<List<LocationSound>> sharedSounds(String orgId, SoundModel model);
  Future<void> shareSound(String orgId, LocationSound sound, SoundModel model);

  /// Opens the alarm (or joins the one already open) and returns its id.
  Future<String> reportAlarm(String orgId, SoundKind kind);
  Future<void> answerAlarm(String orgId, String eventId, String userId, AlarmAnswerStatus status);
  Future<List<AlarmEvent>> openAlarms(String orgId);
  Future<List<AlarmAnswer>> alarmAnswers(String eventId);
  Future<void> closeAlarm(String eventId);
}

class SupabaseOrgStore implements OrgStore {
  SupabaseOrgStore(this._client);

  final SupabaseClient _client;

  @override
  Future<List<OrgMembership>> myOrganizations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('org_members')
        .select('org_id, role, experience, organizations(name)')
        .eq('user_id', userId)
        .order('joined_at');
    return [
      for (final row in rows)
        OrgMembership(
          orgId: row['org_id'] as String,
          orgName: (row['organizations'] as Map<String, dynamic>)['name'] as String,
          role: OrgRole.values.byName(row['role'] as String),
          experience: MemberExperience.values.byName(row['experience'] as String? ?? 'standard'),
        ),
    ];
  }

  @override
  Future<List<OrgInvite>> myInvites() async {
    final rows = await _client.rpc('my_invites') as List<dynamic>;
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        OrgInvite(
          id: row['id'] as String,
          orgId: row['org_id'] as String,
          orgName: row['org_name'] as String,
          role: OrgRole.values.byName(row['role'] as String),
        ),
    ];
  }

  @override
  Future<String> createOrganization(String name) async =>
      await _client.rpc('create_organization', params: {'org_name': name.trim()}) as String;

  @override
  Future<String> acceptInvite(String inviteId) async =>
      await _client.rpc('accept_invite', params: {'invite': inviteId}) as String;

  @override
  Future<void> leave(String orgId, String userId) => removeMember(orgId, userId);

  @override
  Future<MemberNeeds?> loadNeeds(String orgId, String userId) async {
    final row = await _client
        .from('member_needs')
        .select()
        .eq('org_id', orgId)
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : MemberNeeds.fromRow(row);
  }

  @override
  Future<void> saveNeeds(String orgId, String userId, MemberNeeds needs) async {
    await _client.from('member_needs').upsert({'org_id': orgId, 'user_id': userId, ...needs.toRow()});
  }

  @override
  Future<List<OrgMember>> members(String orgId) async {
    final rows = await _client
        .from('org_members')
        .select('user_id, role, email, display_name, department, experience')
        .eq('org_id', orgId)
        .order('joined_at');
    final needs = await _client.from('member_needs').select().eq('org_id', orgId);
    final byUser = {for (final row in needs) row['user_id'] as String: MemberNeeds.fromRow(row)};
    return [
      for (final row in rows)
        OrgMember(
          userId: row['user_id'] as String,
          role: OrgRole.values.byName(row['role'] as String),
          email: row['email'] as String?,
          displayName: row['display_name'] as String?,
          department: row['department'] as String?,
          needs: byUser[row['user_id']],
          experience: MemberExperience.values.byName(row['experience'] as String? ?? 'standard'),
        ),
    ];
  }

  @override
  Future<List<Announcement>> announcements() async {
    final rows = await _client
        .from('org_announcements')
        .select('id, org_id, title, body, important, created_at, organizations(name)')
        .order('created_at', ascending: false);
    final reads = await _client.from('org_announcement_reads').select('announcement_id');
    final seen = {for (final r in reads) r['announcement_id'] as String};
    return [
      for (final row in rows)
        Announcement(
          id: row['id'] as String,
          orgId: row['org_id'] as String,
          orgName: (row['organizations'] as Map<String, dynamic>?)?['name'] as String? ?? '',
          title: row['title'] as String,
          body: row['body'] as String,
          important: row['important'] as bool,
          createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
          seen: seen.contains(row['id']),
        ),
    ];
  }

  @override
  Future<void> postAnnouncement(String orgId,
          {required String title, required String body, required bool important, required int days}) =>
      _client.rpc('post_announcement', params: {
        'target_org': orgId,
        'title': title.trim(),
        'body': body.trim(),
        'important': important,
        'days': days,
      });

  @override
  Future<void> deleteAnnouncement(String announcementId) =>
      _client.rpc('delete_announcement', params: {'announcement': announcementId});

  @override
  Future<void> markAnnouncementSeen(String announcementId) async {
    // The database fills in who (the caller) and when; marking twice changes nothing.
    await _client
        .from('org_announcement_reads')
        .upsert({'announcement_id': announcementId}, onConflict: 'announcement_id,user_id', ignoreDuplicates: true);
  }

  @override
  Future<Map<String, AnnouncementSeen>> announcementSeen(String orgId) async {
    final rows = await _client.rpc('announcement_seen', params: {'target_org': orgId}) as List<dynamic>;
    return {
      for (final row in rows)
        row['announcement_id'] as String: (seen: row['seen'] as int, audience: row['audience'] as int),
    };
  }

  @override
  Future<String> newJoinCode(String orgId) async =>
      await _client.rpc('new_join_code', params: {'target_org': orgId}) as String;

  @override
  Future<DateTime?> joinCodeInfo(String orgId) async {
    final rows = await _client.rpc('join_code_info', params: {'target_org': orgId}) as List<dynamic>;
    return rows.isEmpty ? null : DateTime.parse(rows.first['expires_at'] as String).toLocal();
  }

  @override
  Future<void> revokeJoinCode(String orgId) => _client.rpc('revoke_join_code', params: {'target_org': orgId});

  @override
  Future<String?> joinWithCode(String code, String name, MemberExperience experience) async {
    try {
      return await _client.rpc('join_with_code', params: {
        'code': code,
        'member_name': name.trim(),
        'member_experience': experience.name,
      }) as String?;
    } on PostgrestException catch (e) {
      if (e.code == 'EJ002') throw const JoinCodeTooManyAttempts();
      rethrow;
    }
  }

  @override
  Future<void> invite(String orgId, String email, {OrgRole role = OrgRole.employee, String? department}) async {
    final trimmedDepartment = department?.trim();
    await _client.from('org_invites').insert({
      'org_id': orgId,
      'email': email.trim().toLowerCase(),
      'role': role.name,
      'department': (trimmedDepartment?.isEmpty ?? true) ? null : trimmedDepartment,
    });
  }

  @override
  Future<List<PendingInvite>> pendingInvites(String orgId) async {
    final rows = await _client
        .from('org_invites')
        .select('id, email, role, department')
        .eq('org_id', orgId)
        .isFilter('accepted_at', null)
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false);
    return [
      for (final row in rows)
        PendingInvite(
          id: row['id'] as String,
          email: row['email'] as String,
          role: OrgRole.values.byName(row['role'] as String),
          department: row['department'] as String?,
        ),
    ];
  }

  @override
  Future<void> cancelInvite(String inviteId) async {
    await _client.from('org_invites').delete().eq('id', inviteId);
  }

  @override
  Future<void> setRole(String orgId, String userId, OrgRole role) => guardLastAdmin(
        _client.from('org_members').update({'role': role.name}).eq('org_id', orgId).eq('user_id', userId),
      );

  @override
  Future<void> removeMember(String orgId, String userId) =>
      guardLastAdmin(_client.from('org_members').delete().eq('org_id', orgId).eq('user_id', userId));

  @override
  Future<List<LocationSound>> sharedSounds(String orgId, SoundModel model) async {
    final rows = await _client
        .from('org_location_sounds')
        .select('id, label, level, fingerprint')
        .eq('org_id', orgId)
        .eq('model', model.name);
    return [
      for (final row in rows)
        LocationSound(
          id: 'org-${row['id']}',
          label: row['label'] as String,
          level: AlertLevel.values.byName(row['level'] as String),
          print: Float32List.fromList([for (final v in row['fingerprint'] as List) (v as num).toDouble()]),
        ),
    ];
  }

  @override
  Future<void> shareSound(String orgId, LocationSound sound, SoundModel model) async {
    await _client.from('org_location_sounds').insert({
      'org_id': orgId,
      'label': sound.label,
      'level': sound.level.name,
      'model': model.name,
      'fingerprint': sound.print.toList(),
    });
  }

  @override
  Future<String> reportAlarm(String orgId, SoundKind kind) async => await _client.rpc(
        'report_alarm',
        params: {'target_org': orgId, 'target_location': null, 'alarm_kind': kind.name},
      ) as String;

  @override
  Future<void> answerAlarm(String orgId, String eventId, String userId, AlarmAnswerStatus status) async {
    // The database stamps the time of the answer.
    final change = {'status': status.db};
    try {
      await _client.from('alarm_acks').insert({'event_id': eventId, 'org_id': orgId, 'user_id': userId, ...change});
    } on PostgrestException catch (e) {
      // Answered before: only the status may change (an upsert would rewrite the keys, which is not allowed).
      if (e.code != '23505') rethrow;
      await _client.from('alarm_acks').update(change).eq('event_id', eventId).eq('user_id', userId);
    }
  }

  @override
  Future<List<AlarmEvent>> openAlarms(String orgId) async {
    final rows = await _client
        .from('alarm_events')
        .select('id, kind, started_at')
        .eq('org_id', orgId)
        .isFilter('ended_at', null)
        .order('started_at', ascending: false);
    return [
      for (final row in rows)
        AlarmEvent(
          id: row['id'] as String,
          kind: row['kind'] as String,
          startedAt: DateTime.parse(row['started_at'] as String).toLocal(),
        ),
    ];
  }

  @override
  Future<List<AlarmAnswer>> alarmAnswers(String eventId) async {
    final rows = await _client.from('alarm_acks').select('user_id, status, acked_at').eq('event_id', eventId);
    return [
      for (final row in rows)
        AlarmAnswer(
          userId: row['user_id'] as String,
          status: AlarmAnswerStatus.fromDb(row['status'] as String),
          at: DateTime.parse(row['acked_at'] as String).toLocal(),
        ),
    ];
  }

  @override
  Future<void> closeAlarm(String eventId) async {
    // The database replaces this with its own time.
    await _client.from('alarm_events').update({'ended_at': DateTime.now().toUtc().toIso8601String()}).eq('id', eventId);
  }
}
