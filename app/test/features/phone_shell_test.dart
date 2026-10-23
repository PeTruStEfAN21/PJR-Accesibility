import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/services.dart';
import 'package:pjr_accesibilitate/features/home/echo_home.dart';
import 'package:pjr_accesibilitate/features/home/home_screen.dart';
import 'package:pjr_accesibilitate/features/home/phone_shell.dart';
import 'package:pjr_accesibilitate/features/participant/join_screen.dart';
import 'package:pjr_accesibilitate/features/presenter/presenter_screen.dart';
import 'package:pjr_accesibilitate/features/settings/settings_screen.dart';
import 'package:pjr_accesibilitate/features/sounds/sounds_screen.dart';
import 'package:pjr_accesibilitate/l10n/app_localizations.dart';
import 'package:pjr_accesibilitate/settings/app_settings.dart';
import 'package:pjr_accesibilitate/theme/app_theme.dart';

import '../fakes.dart';

Widget app(TestHarness h, {bool web = false}) => ServicesScope(
      services: AppServices(speech: h.speech, sounds: h.sounds),
      child: SettingsScope(
        settings: h.settings,
        child: MaterialApp(
          locale: const Locale('ro'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: buildTheme(h.settings),
          home: EchoHome(web: web),
        ),
      ),
    );

Future<TestHarness> sized(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return TestHarness.create();
}

Finder bar(String label) => find.descendant(of: find.byKey(PhoneShell.barKey), matching: find.text(label));

void main() {
  testWidgets('on a phone a floating bar holds Dashboard, Meeting, Vibrații, Urgență and Setări', (tester) async {
    final h = await sized(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    for (final label in ['Dashboard', 'Meeting', 'Vibrații', 'Urgență', 'Setări']) {
      expect(bar(label), findsOneWidget, reason: label);
    }
    expect(tester.getSemantics(bar('Dashboard')), isSemantics(isSelected: true, isButton: true));
  });

  testWidgets('the bar switches between the main screens', (tester) async {
    final h = await sized(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(bar('Meeting'));
    await tester.pumpAndSettle();
    expect(find.byType(JoinScreen), findsOneWidget);
    expect(tester.getSemantics(bar('Meeting')), isSemantics(isSelected: true, isButton: true));

    await tester.tap(bar('Vibrații'));
    await tester.pumpAndSettle();
    expect(find.byType(SoundsScreen), findsOneWidget);

    await tester.tap(bar('Setări'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('on the phone, Dashboard has no greeting and nothing the bar already holds', (tester) async {
    final h = await sized(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    final home = find.byType(HomeScreen);
    expect(find.text('Bună! Cu ce începem?'), findsNothing);
    for (final gone in ['Conectează-te la speaker', 'Vibrații', 'Vorbesc cu cineva', 'Tu prezinți? Deschide modul prezentator']) {
      expect(find.descendant(of: home, matching: find.text(gone)), findsNothing, reason: gone);
    }
  });

  testWidgets('a screen opened from a tab covers the bar; back brings it again', (tester) async {
    final h = await sized(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await startPresenting(tester);
    expect(find.byType(PresenterScreen), findsOneWidget);
    expect(find.byKey(PhoneShell.barKey), findsNothing);

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(PhoneShell.barKey), findsOneWidget);
  });

  testWidgets('Alarmă without an account says why', (tester) async {
    final h = await sized(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(bar('Urgență'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Conturile nu sunt pornite'), findsOneWidget);
  });

  testWidgets('a laptop has no bar', (tester) async {
    final h = await sized(tester, const Size(1366, 900));
    await tester.pumpWidget(app(h, web: true));
    await tester.pumpAndSettle();
    expect(find.byKey(PhoneShell.barKey), findsNothing);
    expect(find.text('Eu prezint'), findsOneWidget);
  });

  testWidgets('the last thing on a tab ends above the bar, even on a screen with its own padding', (tester) async {
    showLocationSounds = true;
    addTearDown(() => showLocationSounds = false);
    final h = await sized(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(bar('Vibrații'));
    await tester.pumpAndSettle();
    final item = find.text('Învață un sunet');
    final list = find.descendant(of: find.byType(SoundsScreen), matching: find.byType(Scrollable)).first;
    await tester.drag(list, const Offset(0, -5000));
    await tester.pumpAndSettle();
    await tester.drag(list, const Offset(0, -5000));
    await tester.pumpAndSettle();
    final barTop = tester.getTopLeft(find.byKey(PhoneShell.barKey)).dy;
    expect(tester.getBottomLeft(item).dy, lessThanOrEqualTo(barTop));
  });

  testWidgets('at 200% text the bar labels stay whole and all the same size', (tester) async {
    final h = await sized(tester, const Size(390, 844));
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    final heights = {for (final label in ['Dashboard', 'Meeting', 'Vibrații', 'Urgență', 'Setări']) tester.getRect(bar(label)).height.round()};
    expect(heights, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Meeting: choose between joining and presenting', (tester) async {
    final h = await sized(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(bar('Meeting'));
    await tester.pumpAndSettle();

    // Joining is the default: the code field is there.
    expect(tester.getSemantics(find.text('Particip')), isSemantics(isSelected: true, isButton: true));
    expect(find.text('Codul de pe laptopul speakerului'), findsOneWidget);

    await tester.tap(find.text('Prezint'));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.text('Prezint')), isSemantics(isSelected: true, isButton: true));
    expect(find.text('Codul de pe laptopul speakerului'), findsNothing);
    final start = find.text('Pornește meetingul');
    await tester.scrollUntilVisible(start, 200, scrollable: find.byType(Scrollable).last);
    await Scrollable.ensureVisible(tester.element(start), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.byType(PresenterScreen), findsOneWidget);
    expect(find.byKey(PhoneShell.barKey), findsNothing);
  });

  testWidgets('the bar shows Dashboard with a dashboard icon', (tester) async {
    final h = await sized(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(PhoneShell.barKey), matching: find.byIcon(Icons.space_dashboard)), findsOneWidget);
    expect(find.descendant(of: find.byKey(PhoneShell.barKey), matching: find.byIcon(Icons.vibration_outlined)), findsOneWidget);
  });

  testWidgets('main screens open on a large title, without a top bar', (tester) async {
    final h = await sized(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    for (final (label, title) in [('Meeting', 'Meeting'), ('Vibrații', 'Vibrații'), ('Urgență', 'Urgență'), ('Setări', 'Setări')]) {
      await tester.tap(bar(label));
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsNothing, reason: label);
      final heading = find.byWidgetPredicate((w) => w is Text && w.data == title && (w.style?.fontSize ?? 0) >= 30);
      expect(heading, findsOneWidget, reason: label);
    }
  });

  testWidgets('switching tabs crossfades: both screens show for a moment, then only the new one', (tester) async {
    final h = await sized(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(bar('Setări'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsOneWidget);
    final fade = tester.widget<FadeTransition>(
      find.ancestor(of: find.byType(SettingsScreen), matching: find.byType(FadeTransition)).first,
    );
    expect(fade.opacity.value, inExclusiveRange(0, 1));

    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('a tab keeps its state after switching away and back', (tester) async {
    final h = await sized(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(bar('Meeting'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prezint'));
    await tester.pumpAndSettle();
    await tester.tap(bar('Setări'));
    await tester.pumpAndSettle();
    await tester.tap(bar('Meeting'));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.text('Prezint')), isSemantics(isSelected: true, isButton: true));
  });

  testWidgets('tabs slide in from the side of the tab you tapped while the old one slides out the other way',
      (tester) async {
    final h = await sized(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    double shiftOf(Type screen) => tester
        .widget<Transform>(find.ancestor(of: find.byType(screen), matching: find.byType(Transform)).first)
        .transform
        .getTranslation()
        .x;
    double opacityOf(Type screen) => tester
        .widget<FadeTransition>(find.ancestor(of: find.byType(screen), matching: find.byType(FadeTransition)).first)
        .opacity
        .value;

    await tester.tap(bar('Setări'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(shiftOf(SettingsScreen), greaterThan(0), reason: 'Setări is to the right: it comes from the right');
    expect(shiftOf(HomeScreen), lessThan(0), reason: 'Dashboard leaves to the left');
    expect(opacityOf(HomeScreen), lessThan(1));
    await tester.pumpAndSettle();
    expect(shiftOf(SettingsScreen), 0);

    await tester.tap(bar('Dashboard'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(shiftOf(HomeScreen), lessThan(0), reason: 'back to the left: it comes from the left');
    await tester.pumpAndSettle();
  });

  testWidgets('with reduced motion tabs only fade', (tester) async {
    final h = await sized(tester, const Size(390, 844));
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(bar('Setări'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final shift = tester
        .widget<Transform>(find.ancestor(of: find.byType(SettingsScreen), matching: find.byType(Transform)).first)
        .transform
        .getTranslation()
        .x;
    expect(shift, 0);
    await tester.pumpAndSettle();
  });

  testWidgets('Meeting says no more than it needs: no line above the code, none under Tu ții meetingul', (tester) async {
    final h = await sized(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(bar('Meeting'));
    await tester.pumpAndSettle();
    expect(find.text('Scrie codul de pe laptopul speakerului.'), findsNothing);
    expect(find.text('Codul de pe laptopul speakerului'), findsOneWidget);
    await tester.tap(find.text('Prezint'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Echo ascultă sala de pe acest dispozitiv'), findsNothing);
  });

  testWidgets('the other tabs are built ahead, while the app is idle, so the first visit does not stall',
      (tester) async {
    final h = await sized(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    // Built but offstage: nothing visible changed.
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(SettingsScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(SoundsScreen, skipOffstage: false), findsOneWidget);
    expect(tester.getSemantics(bar('Dashboard')), isSemantics(isSelected: true, isButton: true));
  });
}
