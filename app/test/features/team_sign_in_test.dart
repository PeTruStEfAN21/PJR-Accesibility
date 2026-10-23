import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/org/org_store.dart';
import 'package:pjr_accesibilitate/features/organization/org_screen.dart';

import '../fakes.dart';

/// The sign-in screen from the Dashboard, on a phone.
Future<TestHarness> openSignIn(WidgetTester tester, {double height = 844}) async {
  tester.view.physicalSize = Size(390, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await TestHarness.create(accounts: true);
  await tester.pumpWidget(h.app());
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Intră în cont'));
  await tester.pumpAndSettle();
  return h;
}

Future<void> tapText(WidgetTester tester, String text) async {
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

/// An admin's company with a code, as the admin would have made it.
(String, String) companyWithCode(TestHarness h) {
  final org = h.orgStore!.addOrg('Fabrica de pâine');
  h.orgStore!.addMember(org, 'u-sef@firma.ro', role: OrgRole.admin, email: 'sef@firma.ro');
  h.orgStore!.joinCodes['ABCDEFGH'] = org;
  return (org, 'ABCD-EFGH');
}

Future<void> confirmEmail(WidgetTester tester, {String code = '123456'}) async {
  await tester.enterText(find.widgetWithText(TextField, 'Codul din email'), code);
  await tapText(tester, 'Confirmă codul');
}

void main() {
  testWidgets('the sign-in screen asks who you are: Admin or Angajat', (tester) async {
    await openSignIn(tester);
    expect(tester.getSemantics(find.text('Admin')), isSemantics(isSelected: true, isButton: true));
    expect(find.text('Angajat'), findsOneWidget);
    expect(find.text('Continuă cu Google'), findsOneWidget);

    await tapText(tester, 'Angajat');
    expect(tester.getSemantics(find.text('Angajat')), isSemantics(isSelected: true, isButton: true));
    expect(find.widgetWithText(TextField, 'Codul companiei'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Numele tău'), findsOneWidget);
    // Google would leave the page and lose the company code typed here.
    expect(find.text('Continuă cu Google'), findsNothing);
  });

  testWidgets('an admin confirms the email and lands on the company screen to set it up', (tester) async {
    final h = await openSignIn(tester);
    await fill(tester, 'Adresa de email', 'sef@firma.ro');
    await tapText(tester, 'Trimite-mi un cod');
    expect(h.account!.sentCodes, ['sef@firma.ro']);
    await confirmEmail(tester);

    expect(find.byType(OrgScreen), findsOneWidget);
    expect(find.text('Creează o companie'), findsOneWidget);
  });

  testWidgets('an employee joins with the company code, their name and how they use Echo', (tester) async {
    final h = await openSignIn(tester);
    final (org, code) = companyWithCode(h);
    await tapText(tester, 'Angajat');
    await fill(tester, 'Codul companiei', code.toLowerCase().replaceAll('-', ' '));
    await fill(tester, 'Numele tău', 'Ana Pop');
    await tapText(tester, 'Citesc ce se spune');
    expect(tester.getSemantics(find.text('Citesc ce se spune')), isSemantics(isSelected: true, isButton: true));
    // What the company will see is said before anything is sent (GDPR art. 13).
    expect(find.textContaining('Administratorii ei văd numele'), findsOneWidget);
    await fill(tester, 'Adresa de email', 'ana@firma.ro');
    await tapText(tester, 'Trimite-mi un cod');
    await confirmEmail(tester);

    final ana = h.orgStore!.people[org]!['u-ana@firma.ro']!;
    expect(ana.displayName, 'Ana Pop');
    expect(ana.role, OrgRole.employee);
    expect(ana.experience, MemberExperience.visual);
    expect(find.text('Confirmă codul'), findsNothing);
    expect(find.text('Ai intrat în Fabrica de pâine.'), findsOneWidget);
  });

  testWidgets('everything the employee must give is checked before an email is sent', (tester) async {
    // Tall enough that the fields above stay built while the errors show.
    final h = await openSignIn(tester, height: 1800);
    await tapText(tester, 'Angajat');
    await fill(tester, 'Adresa de email', 'ana@firma.ro');
    await tapText(tester, 'Trimite-mi un cod');
    expect(find.text('Codul companiei are 8 litere și cifre, de exemplu ABCD-EFGH.'), findsOneWidget);

    await fill(tester, 'Codul companiei', 'ABCD-EFGH');
    await tapText(tester, 'Trimite-mi un cod');
    expect(find.text('Scrie-ți numele.'), findsOneWidget);

    await fill(tester, 'Numele tău', 'Ana');
    await tapText(tester, 'Trimite-mi un cod');
    expect(find.text('Alege cum folosești Echo.'), findsOneWidget);
    expect(h.account!.sentCodes, isEmpty);
  });

  testWidgets('a wrong company code keeps the employee signed in to type it again', (tester) async {
    final h = await openSignIn(tester);
    final (org, code) = companyWithCode(h);
    await tapText(tester, 'Angajat');
    await fill(tester, 'Codul companiei', 'ZZZZ-ZZZZ');
    await fill(tester, 'Numele tău', 'Ion');
    await tapText(tester, 'Aud ce se spune');
    await fill(tester, 'Adresa de email', 'ion@firma.ro');
    await tapText(tester, 'Trimite-mi un cod');
    await confirmEmail(tester);

    expect(find.text('Codul companiei nu e bun sau a expirat. Cere-l din nou administratorului.'), findsOneWidget);
    expect(h.account!.isSignedIn, isTrue);
    expect(h.orgStore!.people[org]!.containsKey('u-ion@firma.ro'), isFalse);

    await fill(tester, 'Codul companiei', code);
    await tapText(tester, 'Intră în companie');
    expect(h.orgStore!.people[org]!['u-ion@firma.ro']!.experience, MemberExperience.standard);
    expect(find.text('Ai intrat în Fabrica de pâine.'), findsOneWidget);
  });

  testWidgets('too many wrong codes are explained', (tester) async {
    final h = await openSignIn(tester);
    h.orgStore!.tooManyAttempts = true;
    await tapText(tester, 'Angajat');
    await fill(tester, 'Codul companiei', 'ZZZZ-ZZZZ');
    await fill(tester, 'Numele tău', 'Ion');
    await tapText(tester, 'Aud ce se spune');
    await fill(tester, 'Adresa de email', 'ion@firma.ro');
    await tapText(tester, 'Trimite-mi un cod');
    await confirmEmail(tester);
    expect(find.text('Prea multe coduri greșite. Încearcă din nou peste o oră.'), findsOneWidget);
  });

  testWidgets('the admin makes the company code, sees who joined and how each one uses Echo', (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await TestHarness.create(accounts: true);
    final org = h.orgStore!.addOrg('Fabrica de pâine');
    h.orgStore!.addMember(org, 'u-sef@firma.ro', role: OrgRole.admin, email: 'sef@firma.ro');
    h.orgStore!.addMember(org, 'u-ana@firma.ro',
        email: 'ana@firma.ro', displayName: 'Ana Pop', experience: MemberExperience.visual);
    h.orgStore!.addMember(org, 'u-ion@firma.ro',
        email: 'ion@firma.ro', displayName: 'Ion Ene', experience: MemberExperience.standard);
    h.account!.signInAs('sef@firma.ro');
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Contul meu'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Compania mea');

    expect(find.text('Nu ai niciun cod activ.'), findsOneWidget);
    await tapText(tester, 'Generează un cod nou');
    expect(find.text('ABCD-EFGH'), findsOneWidget);
    expect(h.orgStore!.joinCodes['ABCDEFGH'], org);

    Finder typeOf(String name) => find.descendant(
          of: find.ancestor(of: find.text(name), matching: find.byType(ListTile)),
          matching: find.byType(Text),
        );
    expect(tester.widgetList<Text>(typeOf('Ana Pop')).map((t) => t.data), contains('Citește ce se spune'));
    expect(tester.widgetList<Text>(typeOf('Ion Ene')).map((t) => t.data), contains('Aude ce se spune'));

    await tapText(tester, 'Anulează codul');
    expect(h.orgStore!.joinCodes, isEmpty);
    expect(find.text('Nu ai niciun cod activ.'), findsOneWidget);
  });
}
