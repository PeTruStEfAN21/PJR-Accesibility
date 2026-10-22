import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/services.dart';
import 'package:pjr_accesibilitate/features/conversation/conversation_screen.dart';
import 'package:pjr_accesibilitate/features/home/echo_home.dart';
import 'package:pjr_accesibilitate/features/home/phone_shell.dart';
import 'package:pjr_accesibilitate/features/participant/join_screen.dart';
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
  testWidgets('on a phone a floating bar holds Acasă, Meeting, Sunete, Alarmă and Setări', (tester) async {
    final h = await sized(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    for (final label in ['Acasă', 'Meeting', 'Sunete', 'Alarmă', 'Setări']) {
      expect(bar(label), findsOneWidget, reason: label);
    }
    expect(tester.getSemantics(bar('Acasă')), isSemantics(isSelected: true, isButton: true));
  });

  testWidgets('the bar switches between the main screens', (tester) async {
    final h = await sized(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(bar('Meeting'));
    await tester.pumpAndSettle();
    expect(find.byType(JoinScreen), findsOneWidget);
    expect(tester.getSemantics(bar('Meeting')), isSemantics(isSelected: true, isButton: true));

    await tester.tap(bar('Sunete'));
    await tester.pumpAndSettle();
    expect(find.byType(SoundsScreen), findsOneWidget);

    await tester.tap(bar('Setări'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('a card on Acasă switches the bar instead of opening a second copy', (tester) async {
    final h = await sized(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    final card = find.text('Conectează-te la speaker');
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(bar('Meeting')), isSemantics(isSelected: true, isButton: true));
  });

  testWidgets('a screen opened from a tab covers the bar; back brings it again', (tester) async {
    final h = await sized(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    final row = find.text('Vorbesc cu cineva');
    await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
    await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(ConversationScreen), findsOneWidget);
    expect(find.byKey(PhoneShell.barKey), findsNothing);

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(PhoneShell.barKey), findsOneWidget);
  });

  testWidgets('Alarmă without an account says why', (tester) async {
    final h = await sized(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(bar('Alarmă'));
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

  testWidgets('content is not hidden under the bar', (tester) async {
    final h = await sized(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    final scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, -3000));
    await tester.pumpAndSettle();
    // The last thing on Acasă ends above the bar.
    final barTop = tester.getTopLeft(find.byKey(PhoneShell.barKey)).dy;
    final last = find.text('Tu prezinți? Deschide modul prezentator');
    expect(tester.getBottomLeft(last).dy, lessThanOrEqualTo(barTop));
  });

  testWidgets('the last thing on a tab ends above the bar, even on a screen with its own padding', (tester) async {
    final h = await sized(tester, const Size(390, 844));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.tap(bar('Sunete'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -5000));
    await tester.pumpAndSettle();
    final barTop = tester.getTopLeft(find.byKey(PhoneShell.barKey)).dy;
    expect(tester.getBottomLeft(find.text('Învață un sunet')).dy, lessThanOrEqualTo(barTop));
  });
}
