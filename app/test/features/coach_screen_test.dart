import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pjr_accesibilitate/core/services.dart';
import 'package:pjr_accesibilitate/features/coach/coach_screen.dart';
import 'package:pjr_accesibilitate/features/home/home_screen.dart';
import 'package:pjr_accesibilitate/l10n/app_localizations.dart';
import 'package:pjr_accesibilitate/settings/app_settings.dart';

import '../fakes.dart';
import 'coach/signals.dart';

Widget coachApp(TestHarness h, {Widget home = const CoachScreen()}) => ServicesScope(
      services: AppServices(
        speech: h.speech,
        sounds: h.sounds,
        voice: h.voice,
        coachAudio: h.coachAudio,
        alertWindow: h.alertWindow,
        httpClient: h.httpClient,
        channelFactory: (uri) => h.channel..uri = uri,
      ),
      child: SettingsScope(
        settings: h.settings,
        child: MaterialApp(
          locale: const Locale('ro'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: home,
        ),
      ),
    );

/// The microphone hears [samples], in the browser's chunks of 2048.
Future<void> hear(WidgetTester tester, TestHarness h, Float32List samples) async {
  for (var i = 0; i < samples.length; i += 2048) {
    h.coachAudio.controller.add(Float32List.sublistView(samples, i, min(i + 2048, samples.length)));
  }
  await tester.pump();
  await tester.pump();
}

Future<TestHarness> harness(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return TestHarness.create();
}

Future<void> start(WidgetTester tester, {String? code, bool headphones = false}) async {
  if (code != null) await tester.enterText(find.byType(TextField), code);
  if (headphones) await tester.tap(find.text('Folosesc căști'));
  await tester.tap(find.text('Pornește antrenorul'));
  await tester.pumpAndSettle();
}

const tooFast = 'Vorbești prea repede pentru subtitrare';

/// 21 s of a steady voice-like tone: enough for learning a voice.
Float32List tone21() => Float32List.fromList([for (var i = 0; i < 21 * rate; i++) 0.3 * sin(2 * pi * 220 * i / rate)]);

Future<void> learnVoice(WidgetTester tester, String button) async {
  await tester.tap(find.text(button));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Începe'));
  await tester.pump(const Duration(seconds: 21));
  await tester.pumpAndSettle();
}
const overlap = 'Vorbești în același timp cu altcineva';

void main() {
  testWidgets('laptop home: the colleague in an online meeting opens the clarity coach', (tester) async {
    final h = await harness(tester);
    await tester.pumpWidget(coachApp(h, home: const HomeScreen(presenterFirst: true)));
    await tester.tap(find.text('Sunt coleg într-un meeting online'));
    await tester.pumpAndSettle();
    expect(find.text('Antrenorul de claritate'), findsOneWidget);
  });

  testWidgets('fast talk shows "too fast" with its icon, announced to screen readers', (tester) async {
    final h = await harness(tester);
    await tester.pumpWidget(coachApp(h));
    await start(tester);
    expect(find.text('Totul e în regulă: subtitrarea ține pasul.'), findsOneWidget);

    await hear(tester, h, talk(6, 7));
    expect(find.text(tooFast), findsOneWidget);
    expect(find.byIcon(Icons.speed), findsWidgets);
    expect(tester.getSemantics(find.text(tooFast)), isSemantics(isLiveRegion: true));
  });

  testWidgets('without headphones or a learned voice: approximate, and nothing is sent to the team', (tester) async {
    final h = await harness(tester);
    await tester.pumpWidget(coachApp(h));
    await start(tester, code: 'ABC234');
    h.channel.receive({'type': 'joined', 'code': 'ABC234', 'role': 'colleague', 'peers': {'colleague': 2}});
    await tester.pump();

    expect(find.textContaining('alertele sunt aproximative'), findsOneWidget);
    await hear(tester, h, talk(1, 4));
    expect(h.channel.sink.sent.where((m) => m['type'] == 'speaking'), isEmpty);
  });

  testWidgets('with headphones and a team code: speaking goes to the others when it starts and stops', (tester) async {
    final h = await harness(tester);
    await tester.pumpWidget(coachApp(h));
    await start(tester, code: 'abc234', headphones: true);
    expect(h.channel.uri.toString(), contains('/ws/ABC234'));
    expect(h.channel.uri!.queryParameters['role'], 'colleague');
    h.channel.receive({'type': 'joined', 'code': 'ABC234', 'role': 'colleague', 'peers': {'colleague': 2}});
    // The first pump delivers the message, the second draws what it changed.
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('un coleg conectat'), findsOneWidget);

    await hear(tester, h, talk(1, 4));
    final speaking = h.channel.sink.sent.where((m) => m['type'] == 'speaking').toList();
    expect([for (final m in speaking) m['active']], [true, false]);
    expect(speaking.first['id'], speaking.last['id']);
  });

  testWidgets('talking while another colleague talks: overlap; a colleague who left stops counting', (tester) async {
    final h = await harness(tester);
    await tester.pumpWidget(coachApp(h));
    await start(tester, code: 'ABC234', headphones: true);
    h.channel.receive({'type': 'joined', 'code': 'ABC234', 'role': 'colleague', 'peers': {'colleague': 2}});
    h.channel.receive({'type': 'speaking', 'id': 'b', 'active': true, 'ts': 1});
    h.channel.receive({'type': 'peer', 'role': 'colleague', 'connected': false});
    await tester.pump();
    await hear(tester, h, talk(1, 4));
    expect(find.text(overlap), findsNothing);

    h.channel.receive({'type': 'speaking', 'id': 'c', 'active': true, 'ts': 2});
    await tester.pump();
    await hear(tester, h, talk(1, 4));
    expect(find.text(overlap), findsOneWidget);
  });

  testWidgets('the alert window opens above the meeting and follows the alert', (tester) async {
    final h = await harness(tester);
    await tester.pumpWidget(coachApp(h));
    await start(tester);
    await tester.tap(find.text('Arată alertele peste meeting'));
    await tester.pumpAndSettle();
    expect(h.alertWindow.isOpen, isTrue);
    expect(h.alertWindow.shown.last.$1, 'Totul e în regulă: subtitrarea ține pasul.');
    expect(h.alertWindow.shown.last.$3, isFalse);

    await hear(tester, h, talk(6, 7));
    expect(h.alertWindow.shown.last.$1, tooFast);
    expect(h.alertWindow.shown.last.$3, isTrue);

    h.alertWindow.close();
    await tester.pump();
    expect(find.text('Arată alertele peste meeting'), findsOneWidget);
  });

  testWidgets('without Document Picture-in-Picture the button says why', (tester) async {
    final h = await harness(tester);
    h.alertWindow.supported = false;
    await tester.pumpWidget(coachApp(h));
    await start(tester);
    expect(find.textContaining('Chrome sau Edge pe calculator'), findsOneWidget);
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(of: find.text('Arată alertele peste meeting'), matching: find.bySubtype<ButtonStyleButton>()),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('demo mode: short timings, so the long-talk alert comes after a minute and says so', (tester) async {
    final h = await harness(tester);
    await tester.pumpWidget(coachApp(h));
    await tester.tap(find.text('Mod demonstrație'));
    await start(tester);
    await hear(tester, h, talk(15, 4));
    expect(find.text('Ai vorbit un minut fără pauză: lasă loc de întrebări'), findsOneWidget);
  });

  testWidgets('after Stop, learning the voice again still hears the colleague', (tester) async {
    final h = await harness(tester);
    h.voice
      ..available = true
      ..audio = tone21();
    await tester.pumpWidget(coachApp(h));
    await learnVoice(tester, 'Învață-mi vocea');
    await start(tester);
    await tester.tap(find.text('Oprește'));
    await tester.pumpAndSettle();
    await learnVoice(tester, 'Învață din nou');
    expect(find.text('Am auzit prea puțin. Citește din nou textul, cu voce normală.'), findsNothing);
    expect(find.text('Vocea ta e învățată'), findsOneWidget);
  });

  testWidgets('leaving while the voice model loads closes the microphone', (tester) async {
    final h = await harness(tester);
    final loading = Completer<void>();
    h.voice
      ..available = true
      ..starting = loading;
    await tester.pumpWidget(coachApp(h, home: const SizedBox()));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(builder: (_) => const CoachScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Învață-mi vocea'));
    await tester.pump();
    navigator.pop();
    await tester.pumpAndSettle();
    loading.complete();
    await tester.pumpAndSettle();
    expect(h.voice.micOpen, isFalse);
  });

  testWidgets('at a larger text size the team code field keeps its label whole', (tester) async {
    final h = await harness(tester);
    // 1.5 in the test font, whose glyphs are a full em wide, is about 2.5 with a real font.
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(coachApp(h));
    final label = tester.renderObject<RenderParagraph>(find.text('Codul echipei (opțional)'));
    expect(label.size.width, greaterThanOrEqualTo(label.getMaxIntrinsicWidth(double.infinity) - 1));
  });

  testWidgets('the window above the meeting uses the text size the colleague chose', (tester) async {
    final h = await harness(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(coachApp(h));
    await start(tester);
    await tester.tap(find.text('Arată alertele peste meeting'));
    await tester.pumpAndSettle();
    expect(h.alertWindow.textScale, 1.5);
  });

  testWidgets('microphone refused: the colleague is told why and stays on the setup', (tester) async {
    final h = await harness(tester);
    h.coachAudio.available = false;
    await tester.pumpWidget(coachApp(h));
    await start(tester);
    expect(find.textContaining('Nu pot porni microfonul'), findsOneWidget);
    expect(find.text('Pornește antrenorul'), findsOneWidget);
  });

  testWidgets('a team code can be created here', (tester) async {
    final h = await harness(tester);
    h.httpClient = MockClient((request) async => request.url.path == '/api/sessions'
        ? http.Response(jsonEncode({'code': 'XYZ789'}), 201)
        : http.Response('', 404));
    await tester.pumpWidget(coachApp(h));
    await tester.tap(find.text('Creează un cod'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'XYZ789'), findsOneWidget);
  });

  testWidgets('the colleague\'s voice is learned and kept apart from the presenter\'s', (tester) async {
    final h = await harness(tester);
    h.voice
      ..available = true
      ..audio = Float32List.fromList([for (var i = 0; i < 21 * rate; i++) 0.3 * sin(2 * pi * 220 * i / rate)]);
    await tester.pumpWidget(coachApp(h));
    await tester.tap(find.text('Învață-mi vocea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Începe'));
    await tester.pump(const Duration(seconds: 21));
    await tester.pumpAndSettle();

    expect(find.text('Vocea ta e învățată'), findsOneWidget);
    expect(h.settings.coachVoiceprint, isNotNull);
    expect(h.settings.voiceprint, isNull);
  });
}
