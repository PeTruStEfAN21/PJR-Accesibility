import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/org/org_store.dart';
import 'package:pjr_accesibilitate/core/services.dart';
import 'package:pjr_accesibilitate/features/account/sign_in_screen.dart';
import 'package:pjr_accesibilitate/features/home/echo_home.dart';
import 'package:pjr_accesibilitate/features/home/phone_shell.dart';
import 'package:pjr_accesibilitate/features/organization/org_screen.dart';
import 'package:pjr_accesibilitate/features/presenter/presenter_screen.dart';
import 'package:pjr_accesibilitate/l10n/app_localizations.dart';
import 'package:pjr_accesibilitate/settings/app_settings.dart';
import 'package:pjr_accesibilitate/theme/app_theme.dart';
import 'package:pjr_accesibilitate/widgets/echo_logo.dart';

import '../fakes.dart';

Future<TestHarness> phone(WidgetTester tester, {double height = 844}) async {
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return TestHarness.create(accounts: true);
}

Future<void> tapText(WidgetTester tester, String text) async {
  if (find.text(text).evaluate().isEmpty) {
    // Further down a lazy list: scroll until it is built.
    await tester.scrollUntilVisible(find.text(text), 200, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(find.text(text).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> signInWithCode(WidgetTester tester, String email) async {
  await fill(tester, 'Adresa de email', email);
  await tapText(tester, 'Trimite-mi un cod');
  await fill(tester, 'Codul din email', '123456');
  await tapText(tester, 'Confirmă codul');
}

void main() {
  testWidgets('on a phone with accounts, the app opens on sign-in, with the logo large in the middle', (tester) async {
    final h = await phone(tester);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byKey(PhoneShell.barKey), findsNothing);
    expect(find.text('Intră în cont sau creează-ți unul'), findsOneWidget);
    final logo = find.byType(EchoLogo);
    expect(tester.getSize(logo).height, greaterThanOrEqualTo(80));
    expect(tester.getCenter(logo).dx, moreOrLessEquals(390 / 2, epsilon: 1));
  });

  testWidgets('an admin signs in, sees the company screen, and goes back into the app', (tester) async {
    final h = await phone(tester);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await signInWithCode(tester, 'sef@firma.ro');

    expect(find.byType(OrgScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(PhoneShell.barKey), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
  });

  testWidgets('an employee who joins goes straight into the app', (tester) async {
    final h = await phone(tester, height: 1800);
    final org = h.orgStore!.addOrg('Fabrica de pâine');
    h.orgStore!.addMember(org, 'u-sef@firma.ro', role: OrgRole.admin);
    h.orgStore!.joinCodes['ABCDEFGH'] = org;
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tapText(tester, 'Angajat');
    await fill(tester, 'Codul companiei', 'ABCD-EFGH');
    await fill(tester, 'Numele tău', 'Ana Pop');
    await tapText(tester, 'Citesc ce se spune');
    await signInWithCode(tester, 'ana@firma.ro');

    expect(h.orgStore!.people[org]!['u-ana@firma.ro']!.displayName, 'Ana Pop');
    expect(find.byKey(PhoneShell.barKey), findsOneWidget);
    expect(find.text('Ai intrat în Fabrica de pâine.'), findsOneWidget);
  });

  testWidgets('for an employee the email comes first, above the company code', (tester) async {
    final h = await phone(tester, height: 1800);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tapText(tester, 'Angajat');
    final email = tester.getTopLeft(find.widgetWithText(TextField, 'Adresa de email')).dy;
    final code = tester.getTopLeft(find.widgetWithText(TextField, 'Codul companiei')).dy;
    expect(email, lessThan(code));
  });

  testWidgets('someone already signed in goes straight into the app, and signing out comes back here',
      (tester) async {
    final h = await phone(tester);
    h.account!.signInAs('ana@firma.ro');
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.byKey(PhoneShell.barKey), findsOneWidget);

    await h.account!.signOut();
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byKey(PhoneShell.barKey), findsNothing);
  });

  testWidgets('the presenter needs no account: a link opens presenting without signing in', (tester) async {
    final h = await phone(tester);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tapText(tester, 'Prezinți un meeting? Intră fără cont');
    expect(find.byType(PresenterScreen), findsOneWidget);
  });

  testWidgets('the laptop page opens without signing in', (tester) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await TestHarness.create(accounts: true);
    await tester.pumpWidget(ServicesScope(
      services: AppServices(speech: h.speech, sounds: h.sounds, account: h.account, organizations: h.organizations),
      child: SettingsScope(
        settings: h.settings,
        child: MaterialApp(
          locale: const Locale('ro'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: buildTheme(h.settings),
          home: const EchoHome(web: true),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsNothing);
    expect(find.text('Eu prezint'), findsOneWidget);
  });

  testWidgets('a demo account signs in with its password and goes straight into the app', (tester) async {
    final h = await phone(tester);
    h.account!.passwords['ana.demo@echo-app.test'] = 'parola-demo';
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tapText(tester, 'Cont de test pentru demo');

    Finder inSheet(String label) =>
        find.descendant(of: find.byType(BottomSheet), matching: find.widgetWithText(TextField, label));
    await tester.enterText(inSheet('Adresa de email'), 'ana.demo@echo-app.test');
    await tester.enterText(inSheet('Parola'), 'gresita');
    await tapText(tester, 'Intră');
    expect(find.text('Emailul sau parola nu sunt bune.'), findsOneWidget);
    expect(h.account!.isSignedIn, isFalse);

    await tester.enterText(inSheet('Parola'), 'parola-demo');
    await tapText(tester, 'Intră');
    expect(h.account!.user!.email, 'ana.demo@echo-app.test');
    expect(find.byKey(PhoneShell.barKey), findsOneWidget);
    expect(find.byType(OrgScreen), findsNothing);
    expect(h.account!.sentCodes, isEmpty);
  });
}
