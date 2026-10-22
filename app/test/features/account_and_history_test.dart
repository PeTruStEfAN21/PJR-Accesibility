import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';
import 'participant_screen_test.dart' show caption, joinMeeting, settle;

final history = find.text('Meetingurile mele', skipOffstage: false);

Future<void> openHistory(WidgetTester tester) async {
  // The Sounds card pushed the list's last rows past what the list has built.
  await tester.scrollUntilVisible(find.text('Meetingurile mele'), 100);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Meetingurile mele'));
  await tester.pumpAndSettle();
}

/// The system back gesture: pops the top route the way the phone does.
Future<void> goBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('without accounts configured the home screen has no sign-in or history', (tester) async {
    final h = await TestHarness.create();
    await tester.pumpWidget(h.app());

    expect(find.byTooltip('Intră în cont'), findsNothing);
    expect(history, findsNothing);
  });

  testWidgets('signs in with an emailed code, then shows the saved meetings', (tester) async {
    final h = await TestHarness.create(accounts: true);
    await tester.pumpWidget(h.app());
    expect(history, findsNothing);

    await tester.tap(find.byTooltip('Intră în cont'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ana@example.com');
    await tester.tap(find.text('Trimite-mi un cod'));
    await tester.pumpAndSettle();
    expect(h.account!.sentCodes, ['ana@example.com']);
    expect(find.textContaining('ana@example.com'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.text('Confirmă codul'));
    await tester.pumpAndSettle();
    expect(find.text('Nu am putut intra în cont. Verifică datele și încearcă din nou.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Confirmă codul'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmă codul'), findsNothing);
    expect(find.byTooltip('Contul meu'), findsOneWidget);
    expect(history, findsOneWidget);
  });

  testWidgets('an invalid email is explained in text before anything is sent', (tester) async {
    final h = await TestHarness.create(accounts: true);
    await tester.pumpWidget(h.app());
    await tester.tap(find.byTooltip('Intră în cont'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ana');
    await tester.tap(find.text('Trimite-mi un cod'));
    await tester.pumpAndSettle();

    expect(find.text('Adresa de email nu pare corectă'), findsOneWidget);
    expect(h.account!.sentCodes, isEmpty);
  });

  testWidgets('lists saved meetings, opens one and deletes after confirming', (tester) async {
    final h = await TestHarness.create(accounts: true);
    h.account!.signInAs('ana@example.com');
    h.meetings!.add('Planificare', ['Bună ziua', 'Raportul se trimite vineri']);
    await tester.pumpWidget(h.app());
    await openHistory(tester);

    await tester.tap(find.text('Planificare'));
    await tester.pumpAndSettle();
    expect(find.text('Raportul se trimite vineri'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    await goBack(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Șterge meetingul: Planificare'));
    await tester.pumpAndSettle();
    expect(find.text('Ștergi meetingul?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Șterge meetingul'));
    await tester.pumpAndSettle();

    expect(h.meetings!.meetings, isEmpty);
    expect(find.textContaining('Nu ai încă meetinguri salvate'), findsOneWidget);
  });

  testWidgets('cancelling the delete dialog keeps the meeting', (tester) async {
    final h = await TestHarness.create(accounts: true);
    h.account!.signInAs('ana@example.com');
    h.meetings!.add('Planificare', ['Bună ziua']);
    await tester.pumpWidget(h.app());
    await openHistory(tester);

    await tester.tap(find.byTooltip('Șterge meetingul: Planificare'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anulează'));
    await tester.pumpAndSettle();

    expect(h.meetings!.meetings, hasLength(1));
    expect(find.text('Planificare'), findsOneWidget);
  });

  testWidgets('search shows the matching line', (tester) async {
    final h = await TestHarness.create(accounts: true);
    h.account!.signInAs('ana@example.com');
    h.meetings!.add('Planificare', ['Bună ziua', 'Raportul se trimite vineri']);
    h.meetings!.add('Altceva', ['Nimic aici']);
    await tester.pumpWidget(h.app());
    await openHistory(tester);

    await tester.enterText(find.byType(TextField), 'raportul');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Planificare'), findsOneWidget);
    expect(find.text('Altceva'), findsNothing);
    expect(find.text('#2 · Raportul se trimite vineri'), findsOneWidget);
  });

  testWidgets('deleting the account asks first, then signs out', (tester) async {
    final h = await TestHarness.create(accounts: true);
    h.account!.signInAs('ana@example.com');
    await tester.pumpWidget(h.app());

    await tester.tap(find.byTooltip('Contul meu'));
    await tester.pumpAndSettle();
    expect(find.text('Ești conectat ca ana@example.com'), findsOneWidget);
    await tester.tap(find.text('Șterge contul'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nu se poate anula'), findsOneWidget);
    await tester.tap(find.text('Șterge definitiv'));
    await tester.pumpAndSettle();

    expect(h.account!.deleted, isTrue);
    expect(find.byTooltip('Intră în cont'), findsOneWidget);
    expect(history, findsNothing);
  });

  testWidgets('a signed-in participant keeps the meeting in their account', (tester) async {
    final h = await TestHarness.create(accounts: true);
    h.account!.signInAs('ana@example.com');
    await joinMeeting(tester, h);
    expect(find.text('Transcrierea se salvează în contul tău'), findsOneWidget);

    h.channel.receive(caption('c1', 'coordinator', 'Raportul se trimite vineri'));
    await settle(tester);
    await goBack(tester);
    await tester.pumpAndSettle();

    final saved = h.meetings!.meetings.values.single;
    expect([for (final l in h.meetings!.lines[saved.id]!) l.text], ['Raportul se trimite vineri']);
    expect(h.meetings!.finished, {saved.id});
  });

  testWidgets('signed out, nothing is saved', (tester) async {
    final h = await TestHarness.create(accounts: true);
    await joinMeeting(tester, h);
    expect(find.text('Transcrierea se salvează în contul tău'), findsNothing);

    h.channel.receive(caption('c1', 'coordinator', 'Bună ziua'));
    await settle(tester);
    await goBack(tester);
    await tester.pumpAndSettle();

    expect(h.meetings!.meetings, isEmpty);
  });
}
