import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/services.dart';
import 'package:pjr_accesibilitate/features/home/home_screen.dart';
import 'package:pjr_accesibilitate/features/participant/join_screen.dart';
import 'package:pjr_accesibilitate/l10n/app_localizations.dart';
import 'package:pjr_accesibilitate/settings/app_settings.dart';

import '../fakes.dart';

/// The home screen alone, so a test can pick the laptop (presenter-first) layout.
Widget laptopHome(TestHarness h) => ServicesScope(
      services: AppServices(speech: h.speech, sounds: h.sounds),
      child: SettingsScope(
        settings: h.settings,
        child: MaterialApp(
          locale: const Locale('ro'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const HomeScreen(presenterFirst: true),
        ),
      ),
    );

void main() {
  testWidgets('phone: one main action, other tools grouped, presenter as a quiet link', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final h = await TestHarness.create();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.text('Sunt la un meeting'), findsOneWidget);
    expect(find.text('În afara meetingurilor'), findsOneWidget);
    // Visible sound is the pill in the top bar, not a row.
    expect(find.text('Sunetele din jur'), findsNothing);
    expect(find.text('Sunete'), findsOneWidget);
    expect(find.text('Vorbesc cu cineva'), findsOneWidget);
    expect(find.text('Tu prezinți? Deschide modul prezentator'), findsOneWidget);

    await tester.tap(find.text('Sunt la un meeting'));
    await tester.pumpAndSettle();
    expect(find.byType(JoinScreen), findsOneWidget);
  });

  testWidgets('laptop: presenting is the main action, phone-only tools are hidden', (tester) async {
    final h = await TestHarness.create();
    await tester.pumpWidget(laptopHome(h));
    await tester.pumpAndSettle();

    expect(find.text('Eu prezint'), findsOneWidget);
    expect(find.text('Participi la meeting? Intră de aici'), findsOneWidget);
    expect(find.text('Sunete'), findsNothing);
    expect(find.text('Vorbesc cu cineva'), findsNothing);
  });

  testWidgets('first-run tip: "Am înțeles" hides it for good', (tester) async {
    final h = await TestHarness.create();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.text('Prima dată aici?'), findsOneWidget);
    await tester.tap(find.text('Am înțeles'));
    await tester.pumpAndSettle();
    expect(find.text('Prima dată aici?'), findsNothing);
    expect(h.settings.seenTips, contains('home'));
    expect(h.settings.tipsEnabled, isTrue);
  });

  testWidgets('first-run tip: "Sari peste" turns all tips off', (tester) async {
    final h = await TestHarness.create();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sari peste'));
    await tester.pumpAndSettle();
    expect(find.text('Prima dată aici?'), findsNothing);
    expect(h.settings.tipsEnabled, isFalse);
  });

  testWidgets('using the main action counts as having seen the tip', (tester) async {
    final h = await TestHarness.create();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sunt la un meeting'));
    await tester.pumpAndSettle();
    expect(h.settings.seenTips, contains('home'));
  });

  testWidgets('tip state survives a restart', (tester) async {
    final h = await TestHarness.create(prefs: {
      'uiLanguage': 'ro',
      'seenTips': ['home'],
    });
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.text('Prima dată aici?'), findsNothing);
  });

  testWidgets('200% text on a small phone does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final h = await TestHarness.create(prefs: {'uiLanguage': 'ro', 'textScale': 2.0});
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the app is always light, whatever the system theme', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final h = await TestHarness.create();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Sunt la un meeting'))).brightness, Brightness.light);
  });
}
