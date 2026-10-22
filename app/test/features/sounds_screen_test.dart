import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/core/services.dart';
import 'package:pjr_accesibilitate/features/sounds/sounds_screen.dart';

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

  testWidgets('the screen shows that listening goes on after leaving it', (tester) async {
    final h = await TestHarness.create();
    await tester.pumpWidget(h.app());
    await openSounds(tester);

    await tester.tap(find.text('Pornește ascultarea'));
    await tester.pumpAndSettle();
    expect(h.sounds.listening, isTrue);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await openSounds(tester);

    expect(h.sounds.listening, isTrue);
    expect(find.text('Oprește ascultarea'), findsOneWidget);
    expect(find.textContaining('Ascult sunetele din jur'), findsOneWidget);
  });

  testWidgets('while captions run, the screen says listening is paused', (tester) async {
    final h = await TestHarness.create();
    await tester.pumpWidget(h.app());
    await openSounds(tester);
    await tester.tap(find.text('Pornește ascultarea'));
    await tester.pumpAndSettle();

    final listening = ServicesScope.of(tester.element(find.byType(SoundsScreen))).soundListening;
    await listening.hold();
    await tester.pumpAndSettle();
    expect(find.textContaining('pauză'), findsOneWidget);

    await listening.release();
    await tester.pumpAndSettle();
    expect(find.textContaining('Ascult sunetele din jur'), findsOneWidget);
  });
}
