import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/widgets/echo_mascot.dart';
import 'package:pjr_accesibilitate/core/org/org_store.dart';
import 'package:pjr_accesibilitate/core/services.dart';
import 'package:pjr_accesibilitate/features/alerts/alert_controller.dart';
import 'package:pjr_accesibilitate/features/home/home_screen.dart';
import 'package:pjr_accesibilitate/l10n/app_localizations.dart';
import 'package:pjr_accesibilitate/settings/app_settings.dart';
import 'package:pjr_accesibilitate/theme/app_theme.dart';

import '../fakes.dart';

/// Echo Demo with an admin and two employees; [me] is signed in.
Future<(TestHarness, String)> company(WidgetTester tester, {required String me, Size size = const Size(390, 1600)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await TestHarness.create(accounts: true);
  final store = h.orgStore!;
  final org = store.addOrg('Echo Demo');
  store.addMember(org, 'u-sef@firma.ro', role: OrgRole.admin, email: 'sef@firma.ro');
  store.addMember(org, 'u-ana@firma.ro', email: 'ana@firma.ro', experience: MemberExperience.visual);
  store.addMember(org, 'u-ion@firma.ro', email: 'ion@firma.ro');
  h.account!.signInAs(me);
  return (h, org);
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

/// The phone's Dashboard keeps the announcements behind the large mascot: a tap opens them.
Future<void> openAnnouncements(WidgetTester tester) async {
  await tester.tap(find.byType(EchoMascot).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an employee sees the announcement in a simple list and opening it marks it seen', (tester) async {
    final (h, org) = await company(tester, me: 'ana@firma.ro');
    h.orgStore!.addAnnouncement(org, 'Dezinsecție', 'Mâine plecăm toți cu 2 ore mai devreme.', important: true);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await openAnnouncements(tester);

    expect(find.text('Anunțuri'), findsOneWidget);
    expect(find.text('Dezinsecție'), findsOneWidget);
    // Important is a word, not only a colour; a new one is said as "Nou".
    expect(find.text('Important'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Nou')), findsWidgets);

    await tapText(tester, 'Dezinsecție');
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Mâine plecăm toți cu 2 ore mai devreme.')),
        findsOneWidget);
    expect(h.orgStore!.seenBy('u-ana@firma.ro'), hasLength(1));
    // An employee has nothing to manage here.
    expect(find.text('Șterge anunțul'), findsNothing);
    await tester.tapAt(const Offset(195, 40));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Nou')), findsNothing);
  });

  testWidgets('on the phone the announcements are the first thing on the Dashboard', (tester) async {
    final (h, org) = await company(tester, me: 'ana@firma.ro');
    h.orgStore!.addAnnouncement(org, 'Dezinsecție', 'Mâine plecăm toți cu 2 ore mai devreme.');
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.text('Bună! Cu ce începem?'), findsNothing);
    expect(tester.getTopLeft(find.text('Anunțuri')).dy, lessThan(tester.getTopLeft(find.text('Prima dată aici?')).dy));
  });

  testWidgets('while the announcements load, the section does not say there are none', (tester) async {
    final (h, org) = await company(tester, me: 'ana@firma.ro');
    final network = Completer<void>();
    h.orgStore!.announcementsWait = network.future;
    await tester.pumpWidget(h.app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Niciun anunț acum.'), findsNothing);

    network.complete();
    await tester.pumpAndSettle();
    await openAnnouncements(tester);
    expect(find.text('Niciun anunț acum.'), findsOneWidget);
    // Open, the mascot reads its page beside the heading.
    expect(mascot(MascotPose.reading), findsOneWidget);
  });

  testWidgets('on the phone the large mascot says how many are new and opens the list, shrinking into a corner',
      (tester) async {
    final (h, org) = await company(tester, me: 'ana@firma.ro');
    h.orgStore!.addAnnouncement(org, 'Dezinsecție', 'Text');
    h.orgStore!.addAnnouncement(org, 'Ședință', 'Text');
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.text('Ai 2 anunțuri noi!'), findsOneWidget);
    expect(mascot(MascotPose.news), findsOneWidget);
    expect(tester.getSize(mascot(MascotPose.news)).width, 168);
    expect(find.text('Dezinsecție'), findsNothing);
    expect(find.bySemanticsLabel('Ai 2 anunțuri noi!'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Ai 2 anunțuri noi!')), isSemantics(isButton: true, hasTapAction: true));

    await tester.tap(find.text('Ai 2 anunțuri noi!'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final midway = tester.getSize(find.byType(EchoMascot).first).width;
    expect(midway, lessThan(168));
    expect(midway, greaterThan(56));
    await tester.pumpAndSettle();

    expect(find.text('Ai 2 anunțuri noi!'), findsNothing);
    expect(find.text('Dezinsecție'), findsOneWidget);
    expect(tester.getSize(mascot(MascotPose.reading)), const Size(56, 56));
    // Small, it sits at the heading's end.
    expect(tester.getCenter(mascot(MascotPose.reading)).dx, greaterThan(tester.getCenter(find.text('Anunțuri')).dx));
    handle.dispose();
  });

  testWidgets('with nothing new the mascot says Vezi anunțurile!; in high contrast the list is open', (tester) async {
    final (h, org) = await company(tester, me: 'ana@firma.ro');
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.text('Vezi anunțurile!'), findsOneWidget);
    expect(mascot(MascotPose.hello), findsOneWidget);

    h.settings.update((s) => s.highContrast = true);
    await tester.pumpAndSettle();
    expect(find.text('Vezi anunțurile!'), findsNothing);
    expect(find.text('Niciun anunț acum.'), findsOneWidget);
  });

  testWidgets('important announcements come first', (tester) async {
    final (h, org) = await company(tester, me: 'ion@firma.ro');
    h.orgStore!.addAnnouncement(org, 'Urgent', 'Text', important: true, at: DateTime(2026, 10, 22));
    h.orgStore!.addAnnouncement(org, 'Obișnuit', 'Text', at: DateTime(2026, 10, 23));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await openAnnouncements(tester);
    expect(tester.getTopLeft(find.text('Urgent')).dy, lessThan(tester.getTopLeft(find.text('Obișnuit')).dy));
  });

  testWidgets('the admin writes from the Dashboard, then sees in the announcement how many saw it and deletes it',
      (tester) async {
    final (h, org) = await company(tester, me: 'sef@firma.ro');
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await openAnnouncements(tester);
    expect(find.textContaining('Scrie primul anunț pentru echipă'), findsOneWidget);

    await tapText(tester, 'Anunț nou');
    await tapText(tester, 'Publică anunțul');
    expect(find.text('Scrie un titlu și un mesaj.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Titlu'), 'Dezinsecție');
    await tester.enterText(find.widgetWithText(TextField, 'Mesajul'), 'Mâine plecăm toți cu 2 ore mai devreme.');
    await tapText(tester, 'Important');
    expect(find.textContaining('Toți angajații companiei văd anunțul'), findsOneWidget);
    await tapText(tester, 'Publică anunțul');

    final posted = h.orgStore!.posted.single;
    expect((posted.orgId, posted.title, posted.important, posted.days), (org, 'Dezinsecție', true, 7));
    await tapText(tester, 'Dezinsecție');
    expect(find.text('Văzut de 0 din 2'), findsOneWidget);
    await tapText(tester, 'Șterge anunțul');
    expect(find.text('Ștergi anunțul?'), findsOneWidget);
    await tapText(tester, 'Șterge');
    expect(find.text('Dezinsecție'), findsNothing);
    expect(h.orgStore!.announcementsOf(org), isEmpty);
  });

  testWidgets('the admin also writes from Compania mea', (tester) async {
    final (h, org) = await company(tester, me: 'sef@firma.ro', size: const Size(390, 2400));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Contul meu'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Compania mea');
    await tapText(tester, 'Anunț nou');
    await tester.enterText(find.widgetWithText(TextField, 'Titlu'), 'Ședință');
    await tester.enterText(find.widgetWithText(TextField, 'Mesajul'), 'Vineri la 10.');
    await tapText(tester, 'Publică anunțul');
    expect(h.orgStore!.posted.single.orgId, org);
  });

  testWidgets('someone in no company sees no announcements section', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await TestHarness.create(accounts: true);
    h.account!.signInAs('singur@firma.ro');
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.text('Anunțuri'), findsNothing);
  });

  testWidgets("on an employee's laptop page the announcements come first", (tester) async {
    final (h, org) = await company(tester, me: 'ana@firma.ro', size: const Size(1366, 1400));
    h.orgStore!.addAnnouncement(org, 'Dezinsecție', 'Mâine plecăm toți cu 2 ore mai devreme.');
    await tester.pumpWidget(ServicesScope(
      services: AppServices(speech: h.speech, sounds: h.sounds, account: h.account, organizations: h.organizations),
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
    await tester.pumpAndSettle();

    final news = tester.getTopLeft(find.text('Dezinsecție')).dy;
    final join = tester.getTopLeft(find.text('Conectează-te la speaker')).dy;
    final present = tester.getTopLeft(find.text('Eu prezint')).dy;
    expect(news, lessThan(join));
    expect(join, lessThan(present));
  });
}
