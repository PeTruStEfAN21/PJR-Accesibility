import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/services.dart';
import 'package:pjr_accesibilitate/features/alerts/alert_controller.dart';
import 'package:pjr_accesibilitate/features/alerts/sound_alert.dart';
import 'package:pjr_accesibilitate/features/home/home_screen.dart';
import 'package:pjr_accesibilitate/features/sounds/sounds_screen.dart';
import 'package:pjr_accesibilitate/features/sounds/vibration_picker.dart';
import 'package:pjr_accesibilitate/l10n/app_localizations.dart';

import '../fakes.dart';

void main() {
  Future<void> openSounds(WidgetTester tester) async {
    // A tall view, so the Sounds card is on screen without scrolling.
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sunete'));
    await tester.pumpAndSettle();
  }

  AppLocalizations l10nOf(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(SoundsScreen)));

  Finder inRow(String key, String text) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

  testWidgets('the screen shows that listening goes on after leaving it', (tester) async {
    final h = await TestHarness.create();
    await tester.pumpWidget(h.app());
    await openSounds(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(h.sounds.listening, isTrue);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await openSounds(tester);

    expect(h.sounds.listening, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(find.textContaining('Ascult sunetele din jur'), findsOneWidget);
  });

  testWidgets('while captions run, the screen says listening is paused', (tester) async {
    final h = await TestHarness.create();
    await tester.pumpWidget(h.app());
    await openSounds(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    final listening = ServicesScope.of(tester.element(find.byType(SoundsScreen))).soundListening;
    await listening.hold();
    await tester.pumpAndSettle();
    expect(find.textContaining('pauză'), findsOneWidget);

    await listening.release();
    await tester.pumpAndSettle();
    expect(find.textContaining('Ascult sunetele din jur'), findsOneWidget);
  });

  testWidgets('the Sounds screen explains itself and switches listening', (tester) async {
    final h = await TestHarness.create();
    await tester.pumpWidget(h.app());
    await openSounds(tester);
    final l10n = l10nOf(tester);
    final listening = ServicesScope.of(tester.element(find.byType(SoundsScreen))).soundListening;

    expect(find.text(l10n.soundsExplain), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(listening.wanted, isTrue);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(listening.wanted, isFalse);
  });

  testWidgets('each level shows its chosen vibration', (tester) async {
    final h = await TestHarness.create();
    await tester.pumpWidget(h.app());
    await openSounds(tester);

    expect(inRow('level-critical', 'Critic'), findsOneWidget);
    expect(inRow('level-critical', 'Lungă'), findsOneWidget);
    expect(inRow('level-warning', 'Important'), findsOneWidget);
    expect(inRow('level-warning', 'Triplă'), findsOneWidget);
    expect(inRow('level-info', 'Informativ'), findsOneWidget);
    expect(inRow('level-info', 'Scurtă'), findsOneWidget);
  });

  testWidgets('tapping a vibration plays it and chooses it', (tester) async {
    final semantics = tester.ensureSemantics();
    final h = await TestHarness.create();
    await tester.pumpWidget(h.app());
    await openSounds(tester);
    final l10n = l10nOf(tester);

    await tester.tap(find.byKey(const ValueKey('level-info')));
    await tester.pumpAndSettle();
    expect(find.byType(VibrationPicker), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('haptic-strong')));
    await tester.pumpAndSettle();

    expect(h.signals.vibrated, [Haptic.strong]);
    expect(h.signals.clears, 0);
    expect(h.settings.hapticFor(AlertLevel.info), Haptic.strong);
    expect(h.settings.hapticFor(AlertLevel.warning), Haptic.light);
    expect(find.widgetWithText(SnackBar, l10n.vibrationSwapped('Important', 'Scurtă')), findsOneWidget);
    expect(tester.getSemantics(find.byKey(const ValueKey('haptic-strong'))), isSemantics(isSelected: true, isButton: true));
    expect(tester.getSemantics(find.byKey(const ValueKey('haptic-light'))), isSemantics(isSelected: false, isButton: true));
    semantics.dispose();
  });

  testWidgets('tapping the current vibration only plays it', (tester) async {
    final h = await TestHarness.create();
    await tester.pumpWidget(h.app());
    await openSounds(tester);

    await tester.tap(find.byKey(const ValueKey('level-critical')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('haptic-long')));
    await tester.pumpAndSettle();

    expect(h.signals.vibrated, [Haptic.long]);
    expect(find.byType(SnackBar), findsNothing);
    expect(h.settings.alertHaptics, defaultAlertHaptics);
  });

  testWidgets('without a detector the switch is off but vibrations can be chosen', (tester) async {
    final h = await TestHarness.create();
    h.sounds.available = false;
    await tester.pumpWidget(h.app());
    await openSounds(tester);
    final l10n = l10nOf(tester);

    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.value, isFalse);
    expect(toggle.onChanged, isNull);
    expect(find.text(l10n.soundsDetectorMissing), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('level-warning')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('haptic-long')));
    await tester.pumpAndSettle();
    expect(h.settings.hapticFor(AlertLevel.warning), Haptic.long);
    expect(h.settings.hapticFor(AlertLevel.critical), Haptic.strong);
  });

  testWidgets('200% text on a small phone does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 568 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final h = await TestHarness.create(prefs: {'uiLanguage': 'ro', 'textScale': 2.0});
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    final navigator = Navigator.of(tester.element(find.byType(HomeScreen)));
    navigator.push(MaterialPageRoute<void>(builder: (_) => const SoundsScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    navigator.push(MaterialPageRoute<void>(builder: (_) => const VibrationPicker(level: AlertLevel.critical)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('haptic-strong')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
