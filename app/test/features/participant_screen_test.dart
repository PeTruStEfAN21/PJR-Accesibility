import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../fakes.dart';

Future<void> joinMeeting(WidgetTester tester, TestHarness h) async {
  await tester.pumpWidget(h.app());
  await tester.ensureVisible(find.text('Conectează-te la speaker'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Conectează-te la speaker'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).first, 'abc234');
  await tester.tap(find.text('Schimbă'));
  await tester.pump();
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

/// The server's AI endpoints: [answer] for answer-check, [questions] for the room-question ids.
http.Client aiServer({Map<String, Object>? answer, List<int> questions = const []}) => MockClient((request) async {
      final body = switch (request.url.path) {
        '/api/ai/answer-check' => answer ?? {'answered': false, 'answer': '', 'line_ids': <int>[]},
        '/api/ai/questions' => {'question_ids': questions},
        _ => {'detail': 'not found'},
      };
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});
    });

/// Taps „Vreau să întreb”, types the question and sends it; returns the question notify.
Future<Map<String, dynamic>> askQuestion(WidgetTester tester, TestHarness h, String text) async {
  await tester.tap(find.text('Vreau să întreb'));
  await tester.pump();
  await tester.enterText(find.widgetWithText(TextField, 'Scrie întrebarea'), text);
  await tester.tap(find.byTooltip('Trimite întrebarea'));
  await tester.pump();
  return h.channel.sink.sent.lastWhere((m) => m['kind'] == 'question');
}

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
    await tester.tap(find.text('Conectează-te la speaker'));
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

    // The speaker appears twice: pinned on top and in the list.
    expect(find.text('Bun venit la ședință'), findsNWidgets(2));
    expect(find.text('Speaker'), findsNWidgets(2));
    expect(find.text('Din sală'), findsOneWidget);
    expect(find.bySemanticsLabel('Din sală: Când e termenul?'), findsOneWidget);
  });

  testWidgets('quick message is sent to the presenter and confirmed when seen', (tester) async {
    final h = await TestHarness.create();
    await joinMeeting(tester, h);

    expect(find.text('Am o întrebare'), findsNothing); // replaced by „Vreau să întreb”
    await tester.tap(find.text('Puteți repeta?'));
    await tester.pump();

    final sent = h.channel.sink.sent.single;
    expect(sent['type'], 'notify');
    expect(sent['kind'], 'repeat');
    expect(sent['text'], 'Puteți repeta?');

    h.channel.receive({'type': 'seen', 'id': sent['id'] as String});
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Prezentatorul a văzut: Puteți repeta?'), findsOneWidget);
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
  testWidgets('„Vreau să întreb” alerts the speaker, then sends the typed question', (tester) async {
    final h = await TestHarness.create();
    await joinMeeting(tester, h);

    final question = await askQuestion(tester, h, 'Când e termenul?');

    final notifies = h.channel.sink.sent.where((m) => m['type'] == 'notify').toList();
    expect(notifies.map((m) => m['kind']), ['hand', 'question']);
    expect(notifies.first['text'], '');
    expect(question['text'], 'Când e termenul?');
    expect(find.text('Trimisă, așteaptă să fie citită'), findsOneWidget);
    expect(tester.getSize(find.widgetWithText(FilledButton, 'Vreau să întreb')).height, greaterThanOrEqualTo(48));
  });

  testWidgets('the question shows as read when the laptop reads it', (tester) async {
    final h = await TestHarness.create();
    await joinMeeting(tester, h);
    final question = await askQuestion(tester, h, 'Când e termenul?');

    h.channel.receive({'type': 'read', 'id': question['id'] as String, 'by': 'voice'});
    await settle(tester);

    expect(find.text('Citită, se așteaptă răspunsul'), findsOneWidget);
  });

  testWidgets('the answer card shows the question, the answer and the line it came from', (tester) async {
    final h = await TestHarness.create()
      ..httpClient = aiServer(answer: {'answered': true, 'answer': 'Vineri la prânz.', 'line_ids': [1]});
    await joinMeeting(tester, h);
    final question = await askQuestion(tester, h, 'Când e termenul?');
    h.channel.receive({'type': 'read', 'id': question['id'] as String, 'by': 'voice'});
    await settle(tester);

    h.channel.receive(caption('c1', 'coordinator', 'Termenul e vineri la prânz'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);

    expect(find.text('Ți s-a răspuns'), findsOneWidget);
    expect(find.text('Vineri la prânz.'), findsOneWidget);
    expect(find.text('#1 Termenul e vineri la prânz'), findsOneWidget);

    await tester.tap(find.byTooltip('Închide'));
    await tester.pump();
    expect(find.text('Ți s-a răspuns'), findsNothing);
  });

  testWidgets('a question from the room is marked with an icon and a label', (tester) async {
    final h = await TestHarness.create()..httpClient = aiServer(questions: [1]);
    await joinMeeting(tester, h);

    h.channel.receive(caption('p1', 'public', 'când e termenul'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    expect(find.text('Întrebare din sală'), findsOneWidget);
    expect(find.bySemanticsLabel('Din sală, Întrebare din sală: când e termenul'), findsOneWidget);
  });

  testWidgets('on a small iPhone the answer card leaves room for the live captions', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await TestHarness.create()
      ..httpClient = aiServer(answer: {'answered': true, 'answer': 'Vineri la prânz, după ședința de buget.', 'line_ids': [1, 2]});
    await joinMeeting(tester, h);
    final question = await askQuestion(tester, h, 'Când e termenul pentru raportul trimestrial?');
    h.channel.receive({'type': 'read', 'id': question['id'] as String, 'by': 'voice'});
    h.channel.receive(caption('c1', 'coordinator', 'Termenul pentru raport e vineri la prânz'));
    h.channel.receive(caption('c2', 'coordinator', 'adică imediat după ședința de buget'));
    await settle(tester);
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(find.text('Ți s-a răspuns'), findsOneWidget);

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const Key('captions'))).height, greaterThanOrEqualTo(150));

    // Typing a follow-up question: the quick messages step aside, nothing overflows.
    await tester.tap(find.text('Vreau să întreb'));
    await tester.pump();
    expect(find.text('Puteți repeta?'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const Key('captions'))).height, greaterThanOrEqualTo(100));
  });

  testWidgets('without the speaker connected, „Vreau să întreb” waits and says why', (tester) async {
    final h = await TestHarness.create();
    await joinMeeting(tester, h);
    h.channel.receive({'type': 'peer', 'role': 'presenter', 'connected': false});
    await settle(tester);

    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Vreau să întreb'));
    expect(button.onPressed, isNull);
    expect(find.text('Speakerul nu e conectat încă'), findsOneWidget);
  });

  testWidgets('the phone says when the speaker has seen the raised hand', (tester) async {
    final h = await TestHarness.create();
    await joinMeeting(tester, h);
    await tester.tap(find.text('Vreau să întreb'));
    await tester.pump();
    final hand = h.channel.sink.sent.singleWhere((m) => m['kind'] == 'hand');
    expect(find.text('Speakerul știe că vrei să întrebi'), findsNothing);

    h.channel.receive({'type': 'seen', 'id': hand['id'] as String});
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Speakerul a văzut că vrei să întrebi'), findsOneWidget);
  });
}
