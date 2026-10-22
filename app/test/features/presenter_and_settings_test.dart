import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pjr_accesibilitate/app.dart';
import 'package:pjr_accesibilitate/core/services.dart';

import '../fakes.dart';

Widget presenterApp(TestHarness h) => EchoApp(
      settings: h.settings,
      alerts: h.alerts,
      services: AppServices(
        speech: h.speech,
        sounds: h.sounds,
        channelFactory: (uri) => h.channel..uri = uri,
        httpClient: MockClient((request) async => switch (request.url.path) {
              '/api/sessions' => http.Response(jsonEncode({'code': 'ABC234'}), 201),
              '/api/config' => http.Response(jsonEncode({'public_url': 'http://172.20.10.2:8000'}), 200),
              _ => http.Response('not found', 404),
            }),
      ),
    );

/// Scrolls the (lazy) settings list until [finder] is built and fully on screen, then taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('presenter shows the code, captions speech and marks messages as seen', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final h = await TestHarness.create(prefs: {'uiLanguage': 'ro', 'serverUrl': 'http://localhost:8000'});
    await tester.pumpWidget(presenterApp(h));
    await tester.tap(find.text('Prezint'));
    await tester.pumpAndSettle();

    expect(find.text('A B C 2 3 4'), findsOneWidget);
    expect(h.channel.uri.toString(), 'ws://localhost:8000/ws/ABC234?role=presenter');

    h.channel.receive({'type': 'joined', 'code': 'ABC234', 'role': 'presenter', 'peers': {'presenter': 1}});
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Pornește subtitrarea'));
    await tester.pump();
    h.speech.say('s1', 'Bun venit');
    await tester.pump();
    final caption = h.channel.sink.sent.singleWhere((m) => m['type'] == 'caption');
    expect(caption['speaker'], 'coordinator');
    expect(caption['text'], 'Bun venit');

    h.channel.receive({'type': 'notify', 'id': 'n1', 'kind': 'question', 'text': 'Am o întrebare', 'ts': 1});
    await tester.pump();
    await tester.pump();
    expect(find.text('Am o întrebare'), findsOneWidget);

    await tester.tap(find.text('Am văzut'));
    await tester.pump();
    expect(h.channel.sink.sent.last, {'type': 'seen', 'id': 'n1'});
    expect(find.text('Văzut'), findsOneWidget);
  });

  testWidgets('accessibility settings are applied and saved', (tester) async {
    final h = await TestHarness.create();
    await tester.pumpWidget(h.app());
    await tester.tap(find.byTooltip('Setări'));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('Mod dislexie'));
    expect(h.settings.dyslexiaMode, isTrue);
    expect(Theme.of(tester.element(find.text('Mod dislexie'))).textTheme.bodyLarge!.fontFamily, 'OpenDyslexic');

    await tapVisible(tester, find.text('Tritanopie (albastru greu de văzut)'));
    expect(h.settings.palette.name, 'tritanopia');

    // Back to the top: the first "English" is the app language, the second the spoken one.
    await tester.scrollUntilVisible(find.text('Limba aplicației'), -200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').first);
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  });
}
