import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

Future<void> joinMeeting(WidgetTester tester, TestHarness h) async {
  await tester.pumpWidget(h.app());
  await tester.tap(find.text('Particip la un meeting'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, 'abc234');
  await tester.enterText(find.byType(TextFormField).last, 'http://172.20.10.2:8000');
  await tester.tap(find.text('Intră'));
  await tester.pumpAndSettle();
  h.channel.receive({'type': 'joined', 'code': 'ABC234', 'role': 'participant', 'peers': {'presenter': 1, 'participant': 1}});
  await settle(tester);
}

/// Stream events land in a microtask; the UI they change is drawn on the next frame.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

Map<String, Object> caption(String id, String speaker, String text) =>
    {'type': 'caption', 'id': id, 'speaker': speaker, 'text': text, 'final': true, 'lang': 'ro-RO', 'ts': 1};

void main() {
  testWidgets('joins the meeting by code and shows who is connected', (tester) async {
    final h = await TestHarness.create();
    await joinMeeting(tester, h);

    expect(h.channel.uri.toString(), 'ws://172.20.10.2:8000/ws/ABC234?role=participant');
    expect(find.textContaining('Prezentatorul e conectat'), findsOneWidget);
    expect(h.settings.serverUrl, 'http://172.20.10.2:8000');
  });

  testWidgets('an invalid code is rejected before connecting', (tester) async {
    final h = await TestHarness.create();
    await tester.pumpWidget(h.app());
    await tester.tap(find.text('Particip la un meeting'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'abc');
    await tester.tap(find.text('Intră'));
    await tester.pumpAndSettle();

    expect(find.text('Codul are 6 litere și cifre'), findsOneWidget);
    expect(h.channel.uri, isNull);
  });

  testWidgets('captions show the role as a text label, not only a colour', (tester) async {
    final h = await TestHarness.create();
    await joinMeeting(tester, h);

    h.channel.receive(caption('c1', 'coordinator', 'Bun venit la ședință'));
    h.channel.receive(caption('c2', 'public', 'Când e termenul?'));
    await settle(tester);

    // Coordinator appears twice: pinned on top and in the list.
    expect(find.text('Bun venit la ședință'), findsNWidgets(2));
    expect(find.text('Coordonator'), findsNWidgets(2));
    expect(find.text('Public'), findsOneWidget);
    expect(find.bySemanticsLabel('Public: Când e termenul?'), findsOneWidget);
  });

  testWidgets('quick message is sent to the presenter and confirmed when seen', (tester) async {
    final h = await TestHarness.create();
    await joinMeeting(tester, h);

    await tester.tap(find.text('Am o întrebare'));
    await tester.pump();

    final sent = h.channel.sink.sent.single;
    expect(sent['type'], 'notify');
    expect(sent['kind'], 'question');
    expect(sent['text'], 'Am o întrebare');

    h.channel.receive({'type': 'seen', 'id': sent['id'] as String});
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Prezentatorul a văzut: Am o întrebare'), findsOneWidget);
  });

  testWidgets('the phone captions the audience but drops echoes of the presenter', (tester) async {
    final h = await TestHarness.create();
    await joinMeeting(tester, h);
    await tester.tap(find.byTooltip('Ascultă și sala'));
    await tester.pump();
    expect(h.speech.localeId, 'ro-RO');

    h.channel.receive(caption('c1', 'coordinator', 'Discutăm bugetul pe trimestrul trei'));
    await tester.pump();
    h.speech.say('p1', 'discutăm bugetul pe trimestrul');
    await tester.pump();
    expect(h.channel.sink.sent.where((m) => m['type'] == 'caption'), isEmpty);

    await tester.pump(const Duration(seconds: 3));
    h.speech.say('p2', 'Cine pregătește raportul?');
    await tester.pump();
    final sent = h.channel.sink.sent.where((m) => m['type'] == 'caption').single;
    expect(sent['speaker'], 'public');
    expect(sent['text'], 'Cine pregătește raportul?');
  });
}
