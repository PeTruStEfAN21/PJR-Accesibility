import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pjr_accesibilitate/app.dart';
import 'package:pjr_accesibilitate/core/services.dart';
import 'package:pjr_accesibilitate/core/speech/speech_service.dart';

import '../fakes.dart';

Widget presenterApp(TestHarness h) => EchoApp(
      settings: h.settings,
      alerts: h.alerts,
      services: AppServices(
        speech: h.speech,
        sounds: h.sounds,
        tts: h.tts,
        voice: h.voice,
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

/// Opens the presenter page on a wide window, connected to the session. With [voice] the laptop can
/// recognise voices and the page starts by learning the speaker's.
Future<TestHarness> openPresenter(WidgetTester tester, {bool voice = false, Map<String, Object> prefs = const {}}) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await TestHarness.create(prefs: {'uiLanguage': 'ro', 'serverUrl': 'http://localhost:8000', ...prefs});
  h.voice.available = voice;
  await tester.pumpWidget(presenterApp(h));
  await tester.tap(find.text('Prezint'));
  await tester.pumpAndSettle();
  h.channel.receive({'type': 'joined', 'code': 'ABC234', 'role': 'presenter', 'peers': {'presenter': 1}});
  await tester.pump();
  await tester.pump();
  return h;
}

Future<void> receiveQuestion(WidgetTester tester, TestHarness h, String text) async {
  h.channel.receive({'type': 'notify', 'id': 'q1', 'kind': 'question', 'text': text, 'ts': 1});
  await tester.pump();
  await tester.pump();
}

Iterable<Map<String, dynamic>> readMessages(TestHarness h) => h.channel.sink.sent.where((m) => m['type'] == 'read');

Float32List voiceAudio(double voiced, {double silent = 0}) => Float32List.fromList([
      for (var i = 0; i < (voiced * 16000).round(); i++) 0.3 * sin(2 * pi * 220 * i / 16000),
      for (var i = 0; i < (silent * 16000).round(); i++) 0.0,
    ]);

/// A unit vector along axis [i]: the fake speaker model's "voice".
Float32List voiceVector(int i) => Float32List.fromList([for (var j = 0; j < 3; j++) j == i ? 1.0 : 0.0]);

/// Reads the enrollment text for 20 s with [audio] in the microphone.
Future<void> enroll(WidgetTester tester, TestHarness h, Float32List audio) async {
  h.voice
    ..audio = audio
    ..vectorFor = (_) => voiceVector(0);
  await tester.tap(find.text('Începe'));
  await tester.pump();
  // The 20 s recording ends on the first frame after the 20th second.
  await tester.pump(const Duration(seconds: 21));
  await tester.pump();
  await tester.pump();
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

    h.channel.receive({'type': 'notify', 'id': 'n1', 'kind': 'repeat', 'text': 'Puteți repeta?', 'ts': 1});
    await tester.pump();
    await tester.pump();
    expect(find.text('Puteți repeta?'), findsOneWidget);

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

  testWidgets('a raised hand shows a big alert with an icon', (tester) async {
    final h = await openPresenter(tester);
    h.channel.receive({'type': 'notify', 'id': 'h1', 'kind': 'hand', 'text': '', 'ts': 1});
    await tester.pump();
    await tester.pump();

    expect(find.text('Persoana care folosește Echo vrea să pună o întrebare'), findsOneWidget);
    expect(find.byIcon(Icons.front_hand), findsWidgets);
  });

  testWidgets('the question is read aloud by the laptop and the phone is told', (tester) async {
    final h = await openPresenter(tester);
    await receiveQuestion(tester, h, 'Când e termenul?');
    expect(find.text('Când e termenul?'), findsOneWidget);

    await tester.tap(find.text('Citește cu voce tare'));
    await tester.pump();
    await tester.pump();

    expect(h.tts.spoken, ['Când e termenul?']);
    expect(readMessages(h).single, {'type': 'read', 'id': 'q1', 'by': 'voice'});
    expect(find.text('Citită'), findsOneWidget);
  });

  testWidgets('the speaker can read the question themselves', (tester) async {
    final h = await openPresenter(tester);
    await receiveQuestion(tester, h, 'Când e termenul?');

    await tester.tap(find.text('Am citit-o eu'));
    await tester.pump();

    expect(h.tts.spoken, isEmpty);
    expect(readMessages(h).single, {'type': 'read', 'id': 'q1', 'by': 'speaker'});
  });

  testWidgets('captioning pauses while the laptop speaks and resumes even when the voice fails', (tester) async {
    final h = await openPresenter(tester);
    await tester.tap(find.text('Pornește subtitrarea'));
    await tester.pump();
    expect(h.speech.state.value, SpeechState.listening);
    h.tts.autoFinish = false;
    await receiveQuestion(tester, h, 'Când e termenul?');

    await tester.tap(find.text('Citește cu voce tare'));
    await tester.pump();
    expect(h.speech.state.value, SpeechState.idle);

    h.tts.finish(false);
    await tester.pump();
    await tester.pump();
    expect(h.speech.state.value, SpeechState.listening);
    expect(readMessages(h), isEmpty);
    expect(find.text('Nu am putut citi întrebarea; citește-o tu'), findsOneWidget);
  });

  testWidgets('read aloud is disabled when the laptop has no voice for the language', (tester) async {
    final h = await openPresenter(tester);
    h.tts.available = false;
    await receiveQuestion(tester, h, 'Când e termenul?');

    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Citește cu voce tare'));
    expect(button.onPressed, isNull);
    expect(find.text('Laptopul nu are o voce în limba asta; citește-o tu'), findsOneWidget);
  });

  testWidgets('„Vorbesc eu” is a switch', (tester) async {
    await openPresenter(tester);
    await tester.tap(find.text('Vorbesc eu'));
    await tester.pump();
    expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Vorbesc eu')).value, isTrue);
  });

  testWidgets('the presenter page starts by learning the speaker\'s voice', (tester) async {
    final h = await openPresenter(tester, voice: true);

    expect(find.text('Învață vocea ta'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('A B C 2 3 4'), findsNothing);

    h.voice.audio = voiceAudio(20);
    await tester.tap(find.text('Începe'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    await tester.pump();
    await tester.pump();

    expect(find.text('Vocea ta e învățată'), findsOneWidget);
    expect(find.text('A B C 2 3 4'), findsOneWidget);
    expect(h.settings.voiceprint, isNotNull);
  });

  testWidgets('too little speech asks the speaker to read again', (tester) async {
    final h = await openPresenter(tester, voice: true);
    await enroll(tester, h, voiceAudio(5, silent: 15));

    expect(find.text('Am auzit prea puțin. Citește din nou textul, cu voce normală.'), findsOneWidget);
    expect(find.text('Începe'), findsOneWidget);
    expect(find.text('A B C 2 3 4'), findsNothing);
  });

  testWidgets('final captions carry the label decided by the voice', (tester) async {
    final h = await openPresenter(tester, voice: true);
    await enroll(tester, h, voiceAudio(20));
    await tester.tap(find.text('Pornește subtitrarea'));
    await tester.pump();
    List<Map<String, dynamic>> captions() => h.channel.sink.sent.where((m) => m['type'] == 'caption').toList();

    h.voice.vectorFor = (_) => voiceVector(1); // someone else
    h.speech.say('r1', 'Când e termenul', isFinal: false);
    await tester.pump();
    h.speech.say('r1', 'Când e termenul pentru raport');
    await tester.pump();
    await tester.pump();
    expect(captions().last['speaker'], 'public');

    h.voice.vectorFor = (_) => voiceVector(0); // the speaker again
    h.speech.say('s1', 'Termenul e vineri', isFinal: false);
    await tester.pump();
    expect(captions().last['speaker'], 'public'); // a partial line keeps the last decided label
    h.speech.say('s1', 'Termenul e vineri la prânz');
    await tester.pump();
    await tester.pump();
    expect(captions().last['speaker'], 'coordinator');
  });

  testWidgets('a learned voice is remembered, and can be learned again', (tester) async {
    final h = await openPresenter(tester, voice: true, prefs: {'voiceEnrollment': '[1.0, 0.0, 0.0]'});
    expect(find.text('A B C 2 3 4'), findsOneWidget);

    await tester.tap(find.text('Reînvață vocea'));
    await tester.pump();
    expect(find.text('Învață vocea ta'), findsOneWidget);
    expect(h.settings.voiceprint, isNull);
  });

  testWidgets('without voice recognition every line is the speaker\'s and the page goes on', (tester) async {
    final h = await openPresenter(tester);

    expect(find.text('Recunoașterea vocii nu merge în acest browser; toate replicile sunt „Speaker”'), findsOneWidget);
    expect(find.text('A B C 2 3 4'), findsOneWidget);
    await tester.tap(find.text('Pornește subtitrarea'));
    await tester.pump();
    h.speech.say('s1', 'Bun venit');
    await tester.pump();
    await tester.pump();
    expect(h.channel.sink.sent.lastWhere((m) => m['type'] == 'caption')['speaker'], 'coordinator');
  });

  testWidgets('a test meeting keeps each final line and opens the review when captioning stops', (tester) async {
    final h = await openPresenter(tester, voice: true);
    await enroll(tester, h, voiceAudio(20));

    await tester.ensureVisible(find.text('Meeting de test'));
    await tester.tap(find.text('Meeting de test'));
    await tester.pump();
    await tester.ensureVisible(find.text('Pornește subtitrarea'));
    await tester.tap(find.text('Pornește subtitrarea'));
    await tester.pump();
    h.speech.say('s1', 'Bun venit la ședință');
    await tester.pump();
    await tester.pump();
    await tester.ensureVisible(find.text('Oprește subtitrarea'));
    await tester.tap(find.text('Oprește subtitrarea'));
    await tester.pumpAndSettle();

    expect(find.text('Verifică meetingul de test'), findsOneWidget);
    expect(find.text('Bun venit la ședință'), findsOneWidget);
    await tester.tap(find.text('Ascultă'));
    await tester.pump();
    expect(h.voice.played, hasLength(1));
  });
}
