import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/history/meeting_store.dart';
import 'package:pjr_accesibilitate/core/org/activity_store.dart';
import 'package:pjr_accesibilitate/core/org/org_store.dart';
import 'package:pjr_accesibilitate/core/protocol.dart';
import 'package:pjr_accesibilitate/core/server_api.dart';

import '../fakes.dart';
import 'organizations_screens_test.dart' show openCompany, signedIn, tapShown;
import 'participant_screen_test.dart' show caption, joinMeeting, settle;

const _ana = 'ana@firma.ro';
const _anaId = 'u-$_ana';

ActivityEntry entry(
  int id,
  ActivityEvent event, {
  String? actorId = _anaId,
  String? actorEmail = _ana,
  String? subjectId,
  String? subjectEmail,
  String? title,
  String? kind,
  AlarmAnswerStatus? status,
  double? lat,
  double? lon,
  double? accuracy,
}) =>
    ActivityEntry(
      id: id,
      at: DateTime(2026, 10, 23, 9, id % 60),
      event: event,
      actorId: actorId,
      actorEmail: actorEmail,
      subjectUserId: subjectId,
      subjectEmail: subjectEmail,
      title: title,
      alarmKind: kind,
      status: status,
      lat: lat,
      lon: lon,
      accuracyM: accuracy,
    );

Future<void> openMyHistory(WidgetTester tester, TestHarness h) async {
  await tester.pumpWidget(h.app());
  await tester.tap(find.byTooltip('Contul meu'));
  await tester.pumpAndSettle();
  await tapShown(tester, find.text('Istoricul meu'));
}

void main() {
  testWidgets('my history shows each event in words, newest first', (tester) async {
    final h = await signedIn(tester);
    h.activity!.mine.addAll([
      entry(1, ActivityEvent.meetingStarted, title: 'Ședința de vineri'),
      entry(2, ActivityEvent.colleagueAlarmRaised, kind: 'fire', lat: 44.4268, lon: 26.1025, accuracy: 12),
      entry(3, ActivityEvent.orgAlarmAnswered, kind: 'fireAlarm', status: AlarmAnswerStatus.safe),
      entry(4, ActivityEvent.meetingReadByAdmin,
          actorId: 'boss', actorEmail: 'sef@firma.ro', subjectId: _anaId, subjectEmail: _ana, title: 'Ședința de vineri'),
      entry(5, ActivityEvent.meetingEnded),
    ]);
    await openMyHistory(tester, h);

    final sentences = [
      'Ai încheiat meetingul fără titlu',
      'sef@firma.ro (administrator) a citit meetingul tău „Ședința de vineri”',
      'Ai răspuns „în siguranță” la alarma: Incendiu',
      'Ai dat o alarmă: Incendiu',
      'Ai început meetingul „Ședința de vineri”',
    ];
    for (final s in sentences) {
      expect(find.text(s), findsOneWidget);
    }
    final tops = [for (final s in sentences) tester.getTopLeft(find.text(s)).dy];
    expect(tops, [...tops]..sort());
    expect(find.textContaining('44.42680, 26.10250'), findsOneWidget);
    expect(find.textContaining('±12 m'), findsOneWidget);
    // Every row has an icon next to its words.
    expect(find.descendant(of: find.byType(ListTile), matching: find.byType(Icon)), findsAtLeastNWidgets(5));
  });

  testWidgets('my history has an empty state', (tester) async {
    final h = await signedIn(tester);
    await openMyHistory(tester, h);
    expect(find.textContaining('Nu e nimic în istoric încă'), findsOneWidget);
    expect(find.text('Mai vechi'), findsNothing);
  });

  testWidgets('"Mai vechi" loads the next page before the last row shown', (tester) async {
    final h = await signedIn(tester);
    h.activity!.mine.addAll([for (var i = 1; i <= 60; i++) entry(i, ActivityEvent.meetingStarted, title: 'M$i')]);
    await openMyHistory(tester, h);
    expect(h.activity!.pageRequests, [null]);

    await tester.scrollUntilVisible(find.text('Mai vechi'), 400);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mai vechi'));
    await tester.pumpAndSettle();

    expect(h.activity!.pageRequests, [null, 11]);
    await tester.scrollUntilVisible(find.text('Ai început meetingul „M1”'), 400);
    expect(find.text('Ai început meetingul „M1”'), findsOneWidget);
    expect(find.text('Mai vechi'), findsNothing);
  });

  testWidgets('a page with an event this app does not know still offers older rows', (tester) async {
    final h = await signedIn(tester);
    h.activity!.mine.addAll([for (var i = 1; i <= 60; i++) entry(i, ActivityEvent.meetingStarted, title: 'M$i')]);
    // The newest and the oldest rows of the first page are events from a newer version.
    h.activity!.unknownIds.addAll({60, 11});
    await openMyHistory(tester, h);

    await tester.scrollUntilVisible(find.text('Mai vechi'), 400);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mai vechi'));
    await tester.pumpAndSettle();

    expect(h.activity!.pageRequests, [null, 11]);
    expect(find.text('Ai început meetingul „M60”'), findsNothing);
  });

  test('a page of rows keeps the raw count and last id, skipping unknown events', () {
    Map<String, dynamic> row(int id, String event) => {
          'id': id,
          'at': '2026-10-23T09:00:00Z',
          'event': event,
          'actor_id': _anaId,
          'actor_email': _ana,
        };
    final page = ActivityPage.fromRows([row(9, 'meeting_started'), row(8, 'something_new'), row(7, 'something_new')]);
    expect([for (final e in page.entries) e.id], [9]);
    expect(page.rawCount, 3);
    expect(page.lastId, 7);
  });

  testWidgets('an admin sees the company history with who did what', (tester) async {
    final h = await signedIn(tester);
    final org = h.orgStore!.addOrg('Fabrica');
    h.orgStore!.addMember(org, _anaId, role: OrgRole.admin, email: _ana);
    h.activity!.company[org] = [
      entry(7, ActivityEvent.colleagueAlarmRaised, actorId: 'ion', actorEmail: 'ion@firma.ro', kind: 'fire'),
      entry(8, ActivityEvent.meetingReadByAdmin,
          subjectId: 'ion', subjectEmail: 'ion@firma.ro', title: 'Planificare'),
      // An account deleted since: the alarm row stays, with its email only.
      entry(9, ActivityEvent.colleagueAlarmCancelled, actorId: null, actorEmail: null, kind: 'siren'),
    ];
    await openCompany(tester, h);
    await tapShown(tester, find.text('Istoricul companiei'));

    expect(find.text('ion@firma.ro a dat o alarmă: Incendiu'), findsOneWidget);
    expect(find.text('Ai citit meetingul „Planificare”, salvat de ion@firma.ro'), findsOneWidget);
    expect(find.text('Cineva a anulat alarma: Sirenă sau pericol afară'), findsOneWidget);
  });

  testWidgets('an admin opens a company meeting: transcript by role and summary, and the reading is logged',
      (tester) async {
    final h = await signedIn(tester);
    final org = h.orgStore!.addOrg('Fabrica');
    h.orgStore!.addMember(org, _anaId, role: OrgRole.admin, email: _ana);
    final meeting = SavedMeeting(id: 'm9', title: 'Planificare', startedAt: DateTime(2026, 10, 22, 10));
    h.activity!.meetings[org] = [CompanyMeeting(meeting: meeting, ownerId: 'ion', ownerEmail: 'ion@firma.ro')];
    h.activity!.contents['m9'] = CompanyMeetingContent(
      meeting: meeting,
      lang: 'ro-RO',
      ownerEmail: 'ion@firma.ro',
      lines: [
        SavedLine(seq: 1, captionId: 'line-1', speaker: Speaker.coordinator, text: 'Bugetul crește', spokenAt: DateTime(2026)),
        SavedLine(seq: 2, captionId: 'line-2', speaker: Speaker.public, text: 'Cu cât?', spokenAt: DateTime(2026)),
      ],
      summary: const MeetingSummary(summary: 'S-a discutat bugetul.', tasks: [MeetingTask(text: 'Trimite cifrele', owner: 'Ion')]),
    );
    await openCompany(tester, h);
    await tapShown(tester, find.text('Meetingurile companiei'));

    expect(find.textContaining('angajatul vede în istoricul lui'), findsOneWidget);
    expect(find.text('Planificare'), findsOneWidget);
    expect(find.textContaining('ion@firma.ro'), findsOneWidget);
    // Listing does not read anything.
    expect(h.activity!.opened, isEmpty);

    await tapShown(tester, find.text('Planificare'));
    expect(h.activity!.opened, ['m9']);
    expect(find.textContaining('vede în istoricul lui că ai citit'), findsOneWidget);
    expect(find.text('S-a discutat bugetul.'), findsOneWidget);
    expect(find.text('Trimite cifrele'), findsOneWidget);
    expect(find.bySemanticsLabel('Speaker: Bugetul crește'), findsOneWidget);
    expect(find.bySemanticsLabel('Din sală: Cu cât?'), findsOneWidget);
  });

  testWidgets('an employee is told what the company sees, and does not get the admin lists', (tester) async {
    final h = await signedIn(tester);
    final org = h.orgStore!.addOrg('Fabrica');
    h.orgStore!.addMember(org, 'boss', role: OrgRole.admin);
    h.orgStore!.addMember(org, _anaId, email: _ana);
    await openCompany(tester, h);

    expect(find.textContaining('Administratorii pot citi meetingurile'), findsOneWidget);
    expect(find.text('Istoricul companiei'), findsNothing);
    expect(find.text('Meetingurile companiei'), findsNothing);
  });

  testWidgets('an invitation says admins can read meetings saved while in the company', (tester) async {
    final h = await signedIn(tester);
    final org = h.orgStore!.addOrg('Fabrica');
    h.orgStore!.addMember(org, 'boss', role: OrgRole.admin);
    h.orgStore!.invites['i1'] = (orgId: org, email: _ana, role: OrgRole.employee, department: null);
    await openCompany(tester, h);

    expect(find.textContaining('Dacă accepți, administratorii companiei pot citi meetingurile'), findsOneWidget);
  });

  testWidgets('deleting the account says alarm records stay 12 months', (tester) async {
    final h = await signedIn(tester);
    await tester.pumpWidget(h.app());
    await tester.tap(find.byTooltip('Contul meu'));
    await tester.pumpAndSettle();
    await tapShown(tester, find.text('Șterge contul'));
    expect(find.textContaining('Rămân 12 luni, cu emailul tău dar fără legătură cu contul'), findsOneWidget);
    expect(find.textContaining('răspunsurile tale la alarme'), findsOneWidget);
  });

  testWidgets('at 2x text the delete dialog scrolls to its buttons', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await TestHarness.create(prefs: {'uiLanguage': 'ro', 'tipsEnabled': false, 'textScale': 2.0}, accounts: true);
    h.account!.signInAs(_ana);
    await tester.pumpWidget(h.app());
    await tester.tap(find.byTooltip('Contul meu'));
    await tester.pumpAndSettle();
    // At 2x the account list itself is taller than the screen.
    await tester.scrollUntilVisible(find.text('Șterge contul'), 200);
    await tapShown(tester, find.text('Șterge contul'));

    expect(tester.takeException(), isNull);
    expect(find.descendant(of: find.byType(AlertDialog), matching: find.byType(Scrollable)), findsWidgets);
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Șterge definitiv'),
      200,
      scrollable: find.descendant(of: find.byType(AlertDialog), matching: find.byType(Scrollable)).first,
    );
    await tapShown(tester, find.widgetWithText(FilledButton, 'Șterge definitiv'));
    expect(h.account!.deleted, isTrue);
  });

  testWidgets('an admin is told the other admins can read the meetings they save', (tester) async {
    final h = await signedIn(tester);
    final org = h.orgStore!.addOrg('Fabrica');
    h.orgStore!.addMember(org, _anaId, role: OrgRole.admin, email: _ana);
    await openCompany(tester, h);
    expect(find.textContaining('Administratorii pot citi meetingurile'), findsOneWidget);
  });

  group('meeting saved for the company', () {
    testWidgets('a member sees the banner and the meeting is saved with the company', (tester) async {
      final h = await signedIn(tester);
      final org = h.orgStore!.addOrg('Fabrica');
      h.orgStore!.addMember(org, _anaId, email: _ana);
      await h.organizations!.refresh();
      await joinMeeting(tester, h);

      expect(find.text('Meetingul se salvează pentru Fabrica. Administratorii îl pot citi.'), findsOneWidget);
      expect(find.text('Transcrierea se salvează în contul tău'), findsNothing);
      expect(find.byTooltip('Alege compania'), findsNothing);

      h.channel.receive(caption('c1', 'coordinator', 'Bună ziua'));
      await settle(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      final id = h.meetings!.meetings.keys.single;
      expect(h.meetings!.orgOf[id], org);
    });

    testWidgets('with several companies the participant picks one in the banner', (tester) async {
      final h = await signedIn(tester);
      final first = h.orgStore!.addOrg('Fabrica');
      final second = h.orgStore!.addOrg('Atelier');
      h.orgStore!.addMember(first, _anaId, email: _ana);
      h.orgStore!.addMember(second, _anaId, email: _ana);
      await h.organizations!.refresh();
      await joinMeeting(tester, h);

      expect(find.text('Meetingul se salvează pentru Fabrica. Administratorii îl pot citi.'), findsOneWidget);
      await tester.tap(find.byTooltip('Alege compania'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Atelier').last);
      await tester.pumpAndSettle();
      expect(find.text('Meetingul se salvează pentru Atelier. Administratorii îl pot citi.'), findsOneWidget);

      h.channel.receive(caption('c1', 'coordinator', 'Bună ziua'));
      await settle(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(h.meetings!.orgOf[h.meetings!.meetings.keys.single], second);
    });

    testWidgets('removed from the company meanwhile: the meeting is saved personally, and the banner says so',
        (tester) async {
      final h = await signedIn(tester);
      final org = h.orgStore!.addOrg('Fabrica');
      h.orgStore!.addMember(org, 'boss', role: OrgRole.admin);
      h.orgStore!.addMember(org, _anaId, email: _ana);
      await h.organizations!.refresh();
      await joinMeeting(tester, h);
      expect(find.text('Meetingul se salvează pentru Fabrica. Administratorii îl pot citi.'), findsOneWidget);

      // The admin removes Ana while the app still shows the company.
      h.orgStore!.people[org]!.remove(_anaId);
      h.meetings!.goneOrgs.add(org);
      h.channel.receive(caption('c1', 'coordinator', 'Bună ziua'));
      await settle(tester);
      await tester.pump(const Duration(seconds: 30));
      await settle(tester);

      final id = h.meetings!.meetings.keys.single;
      expect(h.meetings!.orgOf[id], isNull);
      expect([for (final l in h.meetings!.lines[id]!) l.text], ['Bună ziua']);
      expect(find.text('Transcrierea se salvează în contul tău'), findsOneWidget);
      expect(find.textContaining('Administratorii îl pot citi'), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    });

    testWidgets('without a company the meeting stays only the participant\'s', (tester) async {
      final h = await signedIn(tester);
      await h.organizations!.refresh();
      await joinMeeting(tester, h);

      expect(find.text('Transcrierea se salvează în contul tău'), findsOneWidget);
      expect(find.textContaining('Administratorii îl pot citi'), findsNothing);

      h.channel.receive(caption('c1', 'coordinator', 'Bună ziua'));
      await settle(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      final id = h.meetings!.meetings.keys.single;
      expect(h.meetings!.orgOf[id], isNull);
    });
  });
}
