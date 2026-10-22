import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pjr_accesibilitate/features/emergency/alarm_api.dart';
import 'package:pjr_accesibilitate/features/emergency/alarm_logic.dart';
import 'package:pjr_accesibilitate/features/emergency/emergency_screen.dart';
import 'package:pjr_accesibilitate/features/emergency/position_source.dart';
import 'package:pjr_accesibilitate/l10n/app_localizations.dart';
import 'package:pjr_accesibilitate/l10n/app_localizations_en.dart';
import 'package:pjr_accesibilitate/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Positions implements PositionSource {
  _Positions({this.fresh = const Position(lat: 44.43, lon: 26.1, accuracyM: 12)});

  final Position? fresh;
  Position? last;

  @override
  Future<Position?> current({Duration timeout = const Duration(seconds: 5), bool ask = true}) async => fresh;

  @override
  Future<Position?> lastKnown({bool ask = true}) async => last;
}

void main() {
  late List<http.Request> requests;
  late List<String> raised;
  late http.Response Function(http.Request) answer;
  Completer<void>? gate;

  http.Response ok(http.Request request) => request.url.path.endsWith('/cancel')
      ? http.Response('{}', 200)
      : http.Response(jsonEncode({'id': 'a1', 'at': 1792800000.0}), 200);

  setUp(() {
    requests = [];
    raised = [];
    answer = ok;
    gate = null;
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    PositionSource? positions,
    double textScale = 1,
    SentAlarmMemory? memory,
    void Function(String id)? onRaised,
  }) async {
    SharedPreferences.setMockInitialValues({'uiLanguage': 'ro'});
    final settings = AppSettings(await SharedPreferences.getInstance());
    final api = AlarmApi(
      Uri.parse('http://server:8000'),
      client: MockClient((request) async {
        requests.add(request);
        await gate?.future;
        return answer(request);
      }),
      token: () => 'tok',
    );
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: MaterialApp(
        locale: const Locale('ro'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        // A launcher in front, so tests can leave the screen and come back.
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => EmergencyScreen(
                  api: api,
                  positions: positions ?? _Positions(),
                  onRaised: onRaised ?? raised.add,
                  memory: memory,
                ),
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> raiseFire(WidgetTester tester) async {
    await tester.tap(find.text('Incendiu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trimite alarma'));
    await tester.pumpAndSettle();
  }

  testWidgets('four kinds with their level in words', (tester) async {
    await pumpScreen(tester);

    for (final name in ['Incendiu', 'Evacuare', 'Sirenă sau pericol afară', 'Pericol la un utilaj']) {
      expect(find.text(name), findsOneWidget);
    }
    for (final kind in AlarmKind.values) {
      expect(find.byIcon(kind.icon), findsOneWidget);
    }
    expect(find.text('Critic'), findsNWidgets(3));
    expect(find.text('Atenție'), findsOneWidget);
    expect(find.text('Alarma se salvează cu contul tău, ora, locul și adresa IP.'), findsOneWidget);
    expect(find.text('Alarma ajunge la colegii aflați la cel mult 500 m.'), findsOneWidget);
  });

  testWidgets('raise flow', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Incendiu'));
    await tester.pumpAndSettle();
    expect(find.text('Trimiți alarma „Incendiu”?'), findsOneWidget);
    await tester.tap(find.text('Trimite alarma'));
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/api/alarms');
    final body = jsonDecode(requests.single.body) as Map;
    expect(body['kind'], 'fire');
    expect(body['lat'], 44.43);
    expect(body['lon'], 26.1);
    expect(find.textContaining('Alarmă trimisă la '), findsOneWidget);
    expect(raised, ['a1']);
  });

  testWidgets('cancelling the dialog sends nothing', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Evacuare'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renunță'));
    await tester.pumpAndSettle();

    expect(find.text('Trimiți alarma „Evacuare”?'), findsNothing);
    expect(requests, isEmpty);
    expect(raised, isEmpty);
  });

  testWidgets('cancel flow', (tester) async {
    await pumpScreen(tester);
    await raiseFire(tester);

    await tester.tap(find.text('Anulează alarma'));
    await tester.pumpAndSettle();
    expect(find.text('Anulezi alarma pentru toți colegii?'), findsOneWidget);
    await tester.tap(find.text('Anulează alarma').last);
    await tester.pumpAndSettle();

    expect(requests.last.url.path, '/api/alarms/a1/cancel');
    expect(find.text('Alarmă anulată'), findsOneWidget);
    // The kinds are back, for a new alarm.
    expect(find.text('Incendiu'), findsOneWidget);
  });

  testWidgets('no position: explains how to fix it', (tester) async {
    await pumpScreen(tester, positions: _Positions(fresh: null));
    await raiseFire(tester);

    expect(
      find.text('Permite accesul la locație din Setări, ca alarma să ajungă la cine e aproape.'),
      findsOneWidget,
    );
    expect(requests, isEmpty);
    expect(raised, isEmpty);
  });

  testWidgets('no fresh fix: the last known one is used', (tester) async {
    await pumpScreen(tester, positions: _Positions(fresh: null)..last = const Position(lat: 1, lon: 2, accuracyM: 30));
    await raiseFire(tester);

    final body = jsonDecode(requests.single.body) as Map;
    expect(body['lat'], 1);
    expect(body['lon'], 2);
  });

  testWidgets('429: tells when to try again', (tester) async {
    answer = (_) => http.Response('{}', 429, headers: {'retry-after': '1200'});
    await pumpScreen(tester);
    await raiseFire(tester);

    expect(find.text('Ai dat deja 3 alarme în ultima oră. Încearcă din nou peste 20 min.'), findsOneWidget);
    expect(raised, isEmpty);
  });

  testWidgets('offline: says to check the internet', (tester) async {
    answer = (_) => throw http.ClientException('down');
    await pumpScreen(tester);
    await raiseFire(tester);

    expect(find.text('Nu ajungem la server. Verifică internetul și încearcă din nou.'), findsOneWidget);
  });

  testWidgets('while sending, the button says so and cannot be pressed twice', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Incendiu'));
    await tester.pumpAndSettle();
    final width = tester.getSize(find.widgetWithText(FilledButton, 'Trimite alarma')).width;

    bool shown(String text) =>
        tester.widget<Visibility>(find.ancestor(of: find.text(text), matching: find.byType(Visibility))).visible;
    expect(shown('Trimite alarma'), isTrue);
    expect(shown('Se trimite…'), isFalse);

    gate = Completer<void>();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(shown('Se trimite…'), isTrue);
    expect(shown('Trimite alarma'), isFalse);
    expect(tester.getSize(find.byType(FilledButton)).width, width);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    gate!.complete();
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    expect(find.textContaining('Alarmă trimisă la '), findsOneWidget);
  });

  testWidgets('the sent alarm can still be cancelled after going back', (tester) async {
    final memory = SentAlarmMemory(clock: () => DateTime.fromMillisecondsSinceEpoch(1792800060000));
    await pumpScreen(tester, memory: memory);
    await raiseFire(tester);

    Navigator.of(tester.element(find.byType(EmergencyScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Anulează alarma'), findsOneWidget);
    expect(find.textContaining('Alarmă trimisă la '), findsOneWidget);

    await tester.tap(find.text('Anulează alarma'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anulează alarma').last);
    await tester.pumpAndSettle();
    expect(requests.last.url.path, '/api/alarms/a1/cancel');

    // Once cancelled, coming back shows the kinds again.
    Navigator.of(tester.element(find.byType(EmergencyScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Anulează alarma'), findsNothing);
    expect(find.text('Incendiu'), findsOneWidget);
  });

  testWidgets('a cancel that fails says the alarm may no longer be active', (tester) async {
    await pumpScreen(tester);
    await raiseFire(tester);
    answer = (_) => http.Response('{}', 404);

    await tester.tap(find.text('Anulează alarma'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anulează alarma').last);
    await tester.pumpAndSettle();

    expect(find.text('Alarma nu mai e activă sau nu a putut fi anulată. Verifică și încearcă din nou.'), findsOneWidget);
    expect(find.text('Alarma nu a plecat. Încearcă din nou.'), findsNothing);
  });

  testWidgets('while cancelling, the button says so', (tester) async {
    await pumpScreen(tester);
    await raiseFire(tester);
    await tester.tap(find.text('Anulează alarma'));
    await tester.pumpAndSettle();

    gate = Completer<void>();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    final busy = tester.widget<Visibility>(find.ancestor(of: find.text('Se anulează…'), matching: find.byType(Visibility)));
    expect(busy.visible, isTrue);
    expect(find.text('Se trimite…'), findsNothing);

    gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Alarmă anulată'), findsOneWidget);
  });

  testWidgets('a server that never answers closes the dialog after 10 s', (tester) async {
    await pumpScreen(tester);
    gate = Completer<void>();
    await tester.tap(find.text('Incendiu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trimite alarma'));
    await tester.pump();
    expect(find.text('Se trimite…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(find.text('Trimiți alarma „Incendiu”?'), findsNothing);
    expect(find.text('Nu ajungem la server. Verifică internetul și încearcă din nou.'), findsOneWidget);
    gate!.complete();
  });

  testWidgets('at 2x text the error shows above the kinds, on screen', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    answer = (_) => throw http.ClientException('down');
    await pumpScreen(tester, textScale: 2);
    await raiseFire(tester);

    final error = find.text('Nu ajungem la server. Verifică internetul și încearcă din nou.');
    expect(error, findsOneWidget);
    // It starts in view, before the kinds (before, it began below all four rows, off screen).
    // At least its first lines are in view; the kinds come after it, below the fold.
    expect(tester.getRect(error).top, lessThan(844 - 120));
    expect(find.text('Incendiu'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('at 2x text the first kind is on screen and opens the confirmation', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpScreen(tester, textScale: 2);

    expect(tester.getRect(find.text('Incendiu')).bottom, lessThan(844));
    await tester.tap(find.text('Incendiu'));
    await tester.pumpAndSettle();
    expect(find.text('Trimiți alarma „Incendiu”?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('English confirmation uses English quotes', () {
    expect(AppLocalizationsEn().emergencyConfirm('Fire'), 'Send the “Fire” alarm?');
  });

  testWidgets('semantics', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final handle = tester.ensureSemantics();
    await pumpScreen(tester, textScale: 2);

    expect(tester.takeException(), isNull);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Incendiu, Critic')),
      isSemantics(label: 'Incendiu, Critic', isButton: true, hasTapAction: true),
    );
    expect(find.bySemanticsLabel('Pericol la un utilaj, Atenție'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}
