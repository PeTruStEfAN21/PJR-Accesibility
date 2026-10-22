import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/services.dart';
import 'package:pjr_accesibilitate/features/emergency/emergency_screen.dart';
import 'package:pjr_accesibilitate/features/home/home_screen.dart';
import 'package:pjr_accesibilitate/features/participant/join_screen.dart';
import 'package:pjr_accesibilitate/features/sounds/sounds_screen.dart';
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

/// The home screen as the browser build shows it, choosing by screen width.
Widget webHome(TestHarness h) => ServicesScope(
      services: AppServices(speech: h.speech, sounds: h.sounds),
      child: SettingsScope(
        settings: h.settings,
        child: MaterialApp(
          locale: const Locale('ro'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const HomeScreen(web: true),
        ),
      ),
    );

void main() {
  testWidgets('browser on a phone-sized screen: the phone app, in the same build', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await TestHarness.create();
    await tester.pumpWidget(webHome(h));
    await tester.pumpAndSettle();
    expect(find.text('Conectează-te la speaker'), findsOneWidget);
    expect(find.text('Eu prezint'), findsNothing);
  });

  testWidgets('browser on a laptop: presenting first, and everything the phone app has too', (tester) async {
    tester.view.physicalSize = const Size(1366, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await TestHarness.create();
    await tester.pumpWidget(webHome(h));
    await tester.pumpAndSettle();
    expect(find.text('Eu prezint'), findsOneWidget);
    expect(find.text('Conectează-te la speaker'), findsOneWidget);
    expect(find.text('Sunete'), findsOneWidget);
    expect(find.text('Vorbesc cu cineva'), findsOneWidget);
    expect(find.text('Sunt coleg într-un meeting online'), findsOneWidget);
    // Joining has its own card now, so the small link is not repeated.
    expect(find.text('Participi la meeting? Intră de aici'), findsNothing);
  });

  testWidgets('phone: the Sounds card says the state and opens the Sounds screen', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final h = await TestHarness.create();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(HomeScreen)));

    expect(find.text(l10n.homeSoundsOff), findsOneWidget);
    ServicesScope.of(tester.element(find.byType(HomeScreen))).soundListening.enable();
    await tester.pumpAndSettle();
    expect(find.text(l10n.homeSoundsOn), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(HomeScreen), matching: find.text(l10n.homeSounds)));
    await tester.pumpAndSettle();
    expect(find.byType(SoundsScreen), findsOneWidget);
  });

  testWidgets('phone: without a detector the card says it is unavailable', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final h = await TestHarness.create();
    h.sounds.available = false;
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.byType(HomeScreen)));

    expect(find.text(l10n.homeSoundsUnavailable), findsOneWidget);

    // Wanting to listen must not make the icon look active when there is no detector.
    // enable() refuses without a detector, so set the remembered choice directly.
    final listening = ServicesScope.of(tester.element(find.byType(HomeScreen))).soundListening;
    listening.wanted = true;
    // ignore: invalid_use_of_protected_member
    listening.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.hearing_disabled), findsOneWidget);
    expect(find.byIcon(Icons.hearing), findsNothing);
  });

  testWidgets('phone: one main action, other tools grouped, presenter as a quiet link', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final h = await TestHarness.create();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.text('Conectează-te la speaker'), findsOneWidget);
    expect(find.text('În afara meetingurilor'), findsOneWidget);
    // Visible sound is its own card under the main action, not a row.
    expect(find.text('Sunetele din jur'), findsNothing);
    expect(find.descendant(of: find.byType(HomeScreen), matching: find.text('Sunete')), findsOneWidget);
    expect(find.text('Vorbesc cu cineva'), findsOneWidget);
    expect(find.text('Tu prezinți? Deschide modul prezentator'), findsOneWidget);

    await tester.tap(find.text('Conectează-te la speaker'));
    await tester.pumpAndSettle();
    expect(find.byType(JoinScreen), findsOneWidget);
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

    await tester.tap(find.text('Conectează-te la speaker'));
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
    expect(Theme.of(tester.element(find.text('Conectează-te la speaker'))).brightness, Brightness.light);
  });

  testWidgets('home: the emergency row appears only when signed in', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final h = await TestHarness.create(accounts: true);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.text('Alarmă de urgență'), findsNothing);

    h.account!.signInAs('a@example.com');
    await tester.pumpAndSettle();
    expect(find.text('Alarmă de urgență'), findsOneWidget);
    expect(find.text('Când aplicația nu aude pericolul'), findsOneWidget);
    expect(find.byIcon(Icons.emergency_share), findsOneWidget);

    await tester.ensureVisible(find.text('Alarmă de urgență'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alarmă de urgență'));
    await tester.pumpAndSettle();
    expect(find.byType(EmergencyScreen), findsOneWidget);
  });
}
