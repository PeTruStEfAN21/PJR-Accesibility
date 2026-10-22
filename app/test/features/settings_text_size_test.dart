import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/features/settings/settings_screen.dart';

import '../fakes.dart';

void main() {
  testWidgets('dragging the text size only grows the preview; the app follows on release', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final h = await TestHarness.create();
    await tester.pumpWidget(h.app());
    await tester.tap(find.byTooltip('Setări'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    double scaleOf(String text) => MediaQuery.textScalerOf(tester.element(find.text(text).first)).scale(1);

    final slider = find.byType(Slider);
    final gesture = await tester.startGesture(tester.getCenter(slider));
    await gesture.moveBy(Offset(tester.getSize(slider).width / 2, 0));
    await tester.pump();

    expect(h.settings.textScale, 1.0);
    expect(scaleOf('Limba aplicației'), 1.0);
    expect(scaleOf('Puteți repeta?'), greaterThan(1.5));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(h.settings.textScale, greaterThan(1.5));
    expect(scaleOf('Limba aplicației'), greaterThan(1.5));
  });
}
