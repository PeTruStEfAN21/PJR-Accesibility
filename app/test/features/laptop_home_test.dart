import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/org/org_store.dart';
import 'package:pjr_accesibilitate/core/services.dart';
import 'package:pjr_accesibilitate/features/alerts/alert_controller.dart';
import 'package:pjr_accesibilitate/features/home/home_screen.dart';
import 'package:pjr_accesibilitate/l10n/app_localizations.dart';
import 'package:pjr_accesibilitate/settings/app_settings.dart';
import 'package:pjr_accesibilitate/theme/app_theme.dart';

import '../fakes.dart';

/// The laptop page for an employee of Echo Demo who takes part as [experience].
Future<TestHarness> laptop(WidgetTester tester, MemberExperience experience, {bool admin = false}) async {
  tester.view.physicalSize = const Size(1366, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await TestHarness.create(accounts: true);
  final org = h.orgStore!.addOrg('Echo Demo');
  h.orgStore!.addMember(org, 'u-sef@firma.ro', role: OrgRole.admin);
  h.orgStore!.addMember(org, 'u-ana@firma.ro',
      email: 'ana@firma.ro', experience: experience, role: admin ? OrgRole.admin : OrgRole.employee);
  h.orgStore!.addAnnouncement(org, 'Dezinsecție', 'Mâine plecăm toți cu 2 ore mai devreme.');
  h.account!.signInAs('ana@firma.ro');
  await tester.pumpWidget(ServicesScope(
    services: AppServices(
      speech: h.speech,
      sounds: h.sounds,
      account: h.account,
      meetings: h.meetings,
      organizations: h.organizations,
    ),
    child: SettingsScope(
      settings: h.settings,
      child: AlertScope(
        controller: h.alerts,
        child: MaterialApp(
          locale: const Locale('ro'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: buildTheme(h.settings),
          home: const HomeScreen(presenterFirst: true),
        ),
      ),
    ),
  ));
  await h.organizations!.refresh();
  await tester.pumpAndSettle();
  return h;
}

double top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text).first).dy;

Finder card(String title) => find.ancestor(of: find.text(title), matching: find.byType(InkWell)).first;

void main() {
  testWidgets('for an employee: announcements first, then joining large, then presenting and vibrations smaller',
      (tester) async {
    await laptop(tester, MemberExperience.visual);
    expect(top(tester, 'Dezinsecție'), lessThan(top(tester, 'Conectează-te la speaker')));
    expect(top(tester, 'Conectează-te la speaker'), lessThan(top(tester, 'Eu prezint')));
    expect(tester.getTopLeft(card('Eu prezint')).dy, moreOrLessEquals(tester.getTopLeft(card('Vibrații')).dy, epsilon: 1));
    expect(tester.getSize(card('Conectează-te la speaker')).width,
        greaterThan(tester.getSize(card('Eu prezint')).width * 1.5));
    // Reading what is said: no emergency to send; the saved meetings stay.
    expect(find.text('Urgență'), findsNothing);
    expect(find.text('Meetingurile mele'), findsOneWidget);
    expect(find.text('Vorbesc cu cineva'), findsNothing);
    expect(find.text('Bună! Cu ce începem?'), findsNothing);
  });

  testWidgets('for an employee who hears: Urgență next to presenting, no vibrations', (tester) async {
    await laptop(tester, MemberExperience.standard);
    expect(top(tester, 'Dezinsecție'), lessThan(top(tester, 'Conectează-te la speaker')));
    expect(find.text('Urgență'), findsOneWidget);
    expect(tester.getTopLeft(card('Eu prezint')).dy, moreOrLessEquals(tester.getTopLeft(card('Urgență')).dy, epsilon: 1));
    expect(find.text('Vibrații'), findsNothing);
    expect(find.text('Meetingurile mele'), findsOneWidget);
    expect(find.text('Vorbesc cu cineva'), findsNothing);
    expect(find.text('Bună! Cu ce începem?'), findsNothing);
  });

  testWidgets('for the admin: no Vibrații card and no Vorbesc cu cineva', (tester) async {
    await laptop(tester, MemberExperience.standard, admin: true);
    expect(find.text('Eu prezint'), findsOneWidget);
    expect(find.text('Conectează-te la speaker'), findsOneWidget);
    expect(find.text('Vibrații'), findsNothing);
    expect(find.text('Vorbesc cu cineva'), findsNothing);
  });
}
