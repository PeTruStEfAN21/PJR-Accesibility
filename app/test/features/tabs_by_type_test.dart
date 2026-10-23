import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/org/org_store.dart';
import 'package:pjr_accesibilitate/features/emergency/emergency_screen.dart';
import 'package:pjr_accesibilitate/features/home/phone_shell.dart';
import 'package:pjr_accesibilitate/features/sounds/sounds_screen.dart';

import '../fakes.dart';

const _all = ['Dashboard', 'Meeting', 'Vibrații', 'Urgență', 'Setări'];

/// A phone signed in as [me], a member of Echo Demo as [role] / [experience] (or in no company).
Future<TestHarness> phone(WidgetTester tester,
    {String me = 'ana@firma.ro', OrgRole? role, MemberExperience experience = MemberExperience.standard}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await TestHarness.create(accounts: true);
  if (role != null) {
    final org = h.orgStore!.addOrg('Echo Demo');
    if (role != OrgRole.admin) h.orgStore!.addMember(org, 'u-sef@firma.ro', role: OrgRole.admin);
    h.orgStore!.addMember(org, 'u-$me', role: role, email: me, experience: experience);
  }
  h.account!.signInAs(me);
  await tester.pumpWidget(h.app());
  await tester.pumpAndSettle();
  return h;
}

List<String> barLabels() => [for (final label in _all) if (inBar(label).evaluate().isNotEmpty) label];

void main() {
  testWidgets('an employee who reads what is said: Dashboard, Meeting, Vibrații, Setări', (tester) async {
    await phone(tester, role: OrgRole.employee, experience: MemberExperience.visual);
    expect(barLabels(), ['Dashboard', 'Meeting', 'Vibrații', 'Setări']);
    await openTab(tester, 'Vibrații');
    expect(find.byType(SoundsScreen), findsOneWidget);
  });

  testWidgets('an employee who hears: Dashboard, Meeting, Urgență, Setări', (tester) async {
    await phone(tester, me: 'ion@firma.ro', role: OrgRole.employee);
    expect(barLabels(), ['Dashboard', 'Meeting', 'Urgență', 'Setări']);
    await openTab(tester, 'Urgență');
    expect(find.byType(EmergencyScreen), findsOneWidget);
  });

  testWidgets('the admin: Dashboard, Meeting, Urgență, Setări', (tester) async {
    await phone(tester, me: 'sef@firma.ro', role: OrgRole.admin);
    expect(barLabels(), ['Dashboard', 'Meeting', 'Urgență', 'Setări']);
  });

  testWidgets('someone in no company keeps all five', (tester) async {
    await phone(tester, me: 'singur@firma.ro');
    expect(barLabels(), _all);
  });

  testWidgets('without the Urgență tab, a colleague emergency still covers the screen', (tester) async {
    final h = await phone(tester, role: OrgRole.employee, experience: MemberExperience.visual);
    h.alarmChannel.receive(
        {'type': 'alarm', 'id': 'a1', 'kind': 'fire', 'at': 1792800000.0, 'lat': 44.0, 'lon': 26.0, 'accuracy_m': 10.0});
    await tester.pump();
    await tester.pump();
    expect(find.text('Incendiu · semnalat de un coleg'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    h.alerts.dismiss();
  });

  testWidgets('the bar slides between the four tabs in their own order', (tester) async {
    await phone(tester, me: 'ion@firma.ro', role: OrgRole.employee);
    await openTab(tester, 'Setări');
    expect(tester.getSemantics(inBar('Setări')), isSemantics(isSelected: true, isButton: true));
    expect(find.byKey(PhoneShell.barKey), findsOneWidget);
  });
}
