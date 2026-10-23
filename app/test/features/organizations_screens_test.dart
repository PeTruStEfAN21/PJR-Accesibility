import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/org/org_store.dart';
import 'package:pjr_accesibilitate/features/alerts/sound_alert.dart';
import 'package:pjr_accesibilitate/features/alerts/yamnet_logic.dart';

import 'package:pjr_accesibilitate/features/sounds/sounds_screen.dart';

import '../fakes.dart';

const _ana = 'ana@firma.ro';
const _anaId = 'u-$_ana';

Future<TestHarness> signedIn(WidgetTester tester) async {
  final h = await TestHarness.create(prefs: {'uiLanguage': 'ro', 'tipsEnabled': false}, accounts: true);
  h.account!.signInAs(_ana);
  return h;
}

Future<void> openCompany(WidgetTester tester, TestHarness h) async {
  await h.organizations!.refresh();
  await tester.pumpWidget(h.app());
  await tester.tap(find.byTooltip('Contul meu'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Compania mea'));
  await tester.pumpAndSettle();
}

Future<void> openSounds(WidgetTester tester) async {
  // A tall view, so the Sounds card is on screen without scrolling.
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpAndSettle();
  await openTab(tester, 'Vibrații');
}

Float32List print(double x) => normalized([x, 1]);

/// Scrolls the target into view first: on the test screen many buttons start below the fold.
Future<void> tapShown(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  // Centred, so it is not under the phone's floating bar.
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  // Learning location sounds is hidden from the Sounds screen for now; these tests keep it working.
  setUp(() => showLocationSounds = true);
  tearDown(() => showLocationSounds = false);

  testWidgets('learns a sound of this place from 3 samples, then deletes it', (tester) async {
    final h = await TestHarness.create(prefs: {'uiLanguage': 'ro', 'tipsEnabled': false});
    h.sounds.samples.addAll([print(1), print(1.1), print(0.9)]);
    await tester.pumpWidget(h.app());
    await openSounds(tester);

    await tapShown(tester, find.text('Învață un sunet'));
    await tester.enterText(find.widgetWithText(TextField, 'Numele sunetului'), 'Alarma halei 2');
    await tapShown(tester, find.text('Critic: ecran roșu până confirmi'));

    final save = find.widgetWithText(FilledButton, 'Salvează sunetul');
    for (var i = 1; i <= 3; i++) {
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tapShown(tester, find.text('Înregistrează o mostră (3 secunde)'));
      expect(find.text('Mostre: $i din 3'), findsOneWidget);
    }
    await tapShown(tester, save);

    final learned = h.locationSounds.learned.single;
    expect(learned.label, 'Alarma halei 2');
    expect(learned.level, AlertLevel.critical);
    expect(find.text('Alarma halei 2'), findsOneWidget);

    await tapShown(tester, find.byTooltip('Șterge sunetul'));
    expect(h.locationSounds.learned, isEmpty);
  });

  testWidgets('a silent sample is not counted and says why', (tester) async {
    final h = await TestHarness.create(prefs: {'uiLanguage': 'ro', 'tipsEnabled': false});
    h.sounds.samples.add(null);
    await tester.pumpWidget(h.app());
    await openSounds(tester);
    await tapShown(tester, find.text('Învață un sunet'));

    await tapShown(tester, find.text('Înregistrează o mostră (3 secunde)'));
    expect(find.textContaining('N-am auzit nimic'), findsOneWidget);
    expect(find.text('Mostre: 0 din 3'), findsOneWidget);
  });

  testWidgets('creates a company and becomes its admin', (tester) async {
    final h = await signedIn(tester);
    await openCompany(tester, h);

    expect(find.text('Nu faci parte din nicio companie.'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Numele companiei'), 'Fabrica');
    await tapShown(tester, find.text('Creează'));

    expect(h.orgStore!.orgNames.values, ['Fabrica']);
    expect(find.text('Angajați'), findsOneWidget);
    expect(find.text(_ana), findsOneWidget);
  });

  testWidgets('accepts an invitation and shares needs, not a diagnosis', (tester) async {
    final h = await signedIn(tester);
    final org = h.orgStore!.addOrg('Fabrica');
    h.orgStore!.addMember(org, 'boss', role: OrgRole.admin);
    h.orgStore!.invites['i1'] = (orgId: org, email: _ana, role: OrgRole.employee, department: 'Producție');
    await openCompany(tester, h);

    expect(find.text('Fabrica te invită să te alături'), findsOneWidget);
    await tapShown(tester, find.text('Acceptă'));

    expect(find.text('Nevoile mele'), findsOneWidget);
    await tapShown(tester, find.text('Alerte pe ceas'));
    await tapShown(tester, find.text('Salvează'));

    final needs = h.orgStore!.needs['$org/$_anaId']!;
    expect(needs.watchAlerts, isTrue);
    expect(needs.captions, isTrue);
  });

  testWidgets('an employee leaves the company after confirming', (tester) async {
    final h = await signedIn(tester);
    final org = h.orgStore!.addOrg('Fabrica');
    h.orgStore!.addMember(org, 'boss', role: OrgRole.admin);
    h.orgStore!.addMember(org, _anaId, email: _ana);
    await openCompany(tester, h);

    await tapShown(tester, find.text('Părăsește compania'));
    expect(find.text('Părăsești Fabrica?'), findsOneWidget);
    await tapShown(tester, find.widgetWithText(FilledButton, 'Părăsește compania'));

    expect(h.orgStore!.people[org]!.containsKey(_anaId), isFalse);
    expect(find.text('Nu faci parte din nicio companie.'), findsOneWidget);
  });

  testWidgets('an admin sees employees with their needs in words and invites by email', (tester) async {
    final h = await signedIn(tester);
    final org = h.orgStore!.addOrg('Fabrica');
    h.orgStore!.addMember(org, _anaId, role: OrgRole.admin, email: _ana);
    h.orgStore!.addMember(org, 'ion', email: 'ion@firma.ro', needs: const MemberNeeds(watchAlerts: true));
    h.orgStore!.addMember(org, 'maria', email: 'maria@firma.ro');
    await openCompany(tester, h);

    expect(find.text('ion@firma.ro'), findsOneWidget);
    expect(find.textContaining('Alerte pe ceas'), findsOneWidget);
    // Ana (the admin) and Maria have not filled theirs in.
    expect(find.textContaining('Nevoile nu sunt completate'), findsNWidgets(2));

    await tester.ensureVisible(find.widgetWithText(TextField, 'Emailul angajatului'));
    await tester.enterText(find.widgetWithText(TextField, 'Emailul angajatului'), 'Nou@Firma.ro');
    await tester.enterText(find.widgetWithText(TextField, 'Departament (opțional)'), 'Logistică');
    await tapShown(tester, find.text('Trimite invitația'));

    final sent = h.orgStore!.invites.values.single;
    expect(sent.email, 'nou@firma.ro');
    expect(sent.department, 'Logistică');
    expect(find.text('nou@firma.ro'), findsOneWidget);
  });

  testWidgets('an admin sees who answered an alarm and closes it', (tester) async {
    final h = await signedIn(tester);
    final store = h.orgStore!;
    final org = store.addOrg('Fabrica');
    store.addMember(org, _anaId, role: OrgRole.admin, email: _ana);
    store.addMember(org, 'ion', email: 'ion@firma.ro');
    store.addMember(org, 'maria', email: 'maria@firma.ro');
    final event = await store.reportAlarm(org, SoundKind.fireAlarm);
    await store.answerAlarm(org, event, 'ion', AlarmAnswerStatus.safe);
    await store.answerAlarm(org, event, 'maria', AlarmAnswerStatus.needHelp);
    await openCompany(tester, h);

    expect(find.text('Alarme în desfășurare'), findsOneWidget);
    expect(find.text('În siguranță: 1'), findsOneWidget);
    expect(find.text('Au nevoie de ajutor: 1'), findsOneWidget);
    expect(find.text('Fără răspuns: 1'), findsOneWidget);
    expect(find.textContaining('maria@firma.ro'), findsWidgets);

    await tapShown(tester, find.text('Închide alarma'));
    expect(await store.openAlarms(org), isEmpty);
    expect(find.text('Nicio alarmă acum.'), findsOneWidget);
  });

  testWidgets('an admin shares a learned sound with the company', (tester) async {
    final h = await signedIn(tester);
    final org = h.orgStore!.addOrg('Fabrica');
    h.orgStore!.addMember(org, _anaId, role: OrgRole.admin, email: _ana);
    await h.locationSounds.add('Alarma halei', AlertLevel.critical, print(1));
    await h.organizations!.refresh();
    await tester.pumpWidget(h.app());
    await openSounds(tester);

    await tapShown(tester, find.byTooltip('Împarte cu compania'));

    final (shared, model) = h.orgStore!.sounds[org]!.single;
    expect(shared.label, 'Alarma halei');
    expect(model, SoundModel.tflite);
    expect(find.text('Sunetul a fost trimis companiei.'), findsOneWidget);
  });

  testWidgets('during a fire alarm an employee answers "I am safe" in one tap', (tester) async {
    final h = await signedIn(tester);
    final org = h.orgStore!.addOrg('Fabrica');
    h.orgStore!.addMember(org, _anaId, email: _ana);
    await h.organizations!.refresh();
    await tester.pumpWidget(h.app());

    h.sounds.controller.add(SoundAlert(SoundKind.fireAlarm, at: DateTime(2026)));
    await tester.pump();
    await tester.pump();
    expect(find.text('Lista nu înlocuiește procedura de evacuare.'), findsOneWidget);
    await tester.tap(find.text('Sunt în siguranță'));
    await tester.pumpAndSettle();

    final event = h.orgStore!.alarms.keys.single;
    expect(h.orgStore!.answers[event]![_anaId]!.status, AlarmAnswerStatus.safe);
    expect(find.text('ALARMĂ DE INCENDIU'), findsNothing);
  });

  testWidgets('"I need help" is sent and the alarm screen stays up', (tester) async {
    final h = await signedIn(tester);
    final org = h.orgStore!.addOrg('Fabrica');
    h.orgStore!.addMember(org, _anaId, email: _ana);
    await h.organizations!.refresh();
    await tester.pumpWidget(h.app());

    h.sounds.controller.add(SoundAlert(SoundKind.siren, at: DateTime(2026)));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Am nevoie de ajutor'));
    await tester.pumpAndSettle();

    final event = h.orgStore!.alarms.keys.single;
    expect(h.orgStore!.answers[event]![_anaId]!.status, AlarmAnswerStatus.needHelp);
    expect(find.text('Răspunsul a fost trimis companiei.'), findsOneWidget);
    expect(find.text('Sirenă'), findsOneWidget);
    await tester.tap(find.text('Am înțeles'));
    await tester.pumpAndSettle();
  });

  testWidgets('without a company the alarm screen has no roll-call buttons', (tester) async {
    final h = await signedIn(tester);
    await h.organizations!.refresh();
    await tester.pumpWidget(h.app());
    h.sounds.controller.add(SoundAlert(SoundKind.fireAlarm, at: DateTime(2026)));
    await tester.pump();
    await tester.pump();
    expect(find.text('Sunt în siguranță'), findsNothing);
    await tester.tap(find.text('Am înțeles'));
    await tester.pumpAndSettle();
  });

  testWidgets('the only admin of a company with colleagues is told why the account was not deleted', (tester) async {
    final h = await signedIn(tester);
    h.account!.deleteError = const LastAdminException();
    await tester.pumpWidget(h.app());
    await tester.tap(find.byTooltip('Contul meu'));
    await tester.pumpAndSettle();

    await tapShown(tester, find.text('Șterge contul'));
    await tapShown(tester, find.widgetWithText(FilledButton, 'Șterge definitiv'));

    expect(find.textContaining('Fă pe altcineva administrator'), findsOneWidget);
    expect(h.account!.deleted, isFalse);
    expect(h.account!.isSignedIn, isTrue);
  });

  testWidgets('the last person in a company can leave it, and the company goes', (tester) async {
    final h = await signedIn(tester);
    final org = h.orgStore!.addOrg('Atelier');
    h.orgStore!.addMember(org, _anaId, role: OrgRole.admin, email: _ana);
    await h.orgStore!.leave(org, _anaId);
    expect(h.orgStore!.people.containsKey(org), isFalse);
  });
}
