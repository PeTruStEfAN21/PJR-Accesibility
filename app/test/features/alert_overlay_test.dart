import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/features/alerts/sound_alert.dart';

import '../fakes.dart';

void main() {
  testWidgets('a detected fire alarm covers any screen with the exit and needs acknowledging', (tester) async {
    final h = await TestHarness.create(prefs: {'uiLanguage': 'ro', 'emergencyExit': 'Scara B'});
    await tester.pumpWidget(h.app());
    await openTab(tester, 'Meeting');

    h.sounds.controller.add(SoundAlert(SoundKind.fireAlarm, at: DateTime(2026)));
    await tester.pump();
    await tester.pump();

    expect(find.text('ALARMĂ DE INCENDIU'), findsOneWidget);
    expect(find.text('Ieșirea cea mai apropiată: Scara B'), findsOneWidget);

    await tester.tap(find.text('Am înțeles'));
    await tester.pump();
    expect(find.text('ALARMĂ DE INCENDIU'), findsNothing);
  });

  testWidgets('the interface switches to English', (tester) async {
    final h = await TestHarness.create(prefs: {'uiLanguage': 'en'});
    await tester.pumpWidget(h.app());
    expect(inBar('Dashboard'), findsOneWidget);
    expect(inBar('Settings'), findsOneWidget);
    h.alerts.dispose();
  });

  testWidgets('a car horn gets its own full warning screen with advice', (tester) async {
    final h = await TestHarness.create(prefs: {'uiLanguage': 'ro', 'tipsEnabled': false});
    await tester.pumpWidget(h.app());
    h.sounds.controller.add(SoundAlert(SoundKind.horn, at: DateTime(2026)));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Claxon în apropiere'), findsOneWidget);
    expect(find.text('ATENȚIE'), findsOneWidget);
    expect(find.textContaining('uită-te în jur'), findsOneWidget);

    await tester.tap(find.text('Am înțeles'));
    await tester.pump();
    expect(find.text('Claxon în apropiere'), findsNothing);
    h.alerts.dispose();
  });

  testWidgets('a critical alert is labelled critical, not only red', (tester) async {
    final h = await TestHarness.create(prefs: {'uiLanguage': 'ro', 'tipsEnabled': false});
    await tester.pumpWidget(h.app());
    h.sounds.controller.add(SoundAlert(SoundKind.siren, at: DateTime(2026)));
    await tester.pump();
    await tester.pump();
    expect(find.text('CRITIC'), findsOneWidget);
    expect(find.text('Sirenă'), findsOneWidget);
    await tester.tap(find.text('Am înțeles'));
    await tester.pump();
    h.alerts.dispose();
  });

  testWidgets('a doorbell stays a small banner and shows without errors', (tester) async {
    final h = await TestHarness.create(prefs: {'uiLanguage': 'ro', 'tipsEnabled': false});
    await tester.pumpWidget(h.app());
    h.sounds.controller.add(SoundAlert(SoundKind.door, at: DateTime(2026)));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Ușă sau sonerie'), findsOneWidget);
    expect(find.text('Am înțeles'), findsNothing);
    h.alerts.dispose();
  });

  testWidgets('a small alert drops in at the top, like a phone notification, and swipes away upward', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await TestHarness.create(prefs: {'uiLanguage': 'ro', 'tipsEnabled': false});
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    h.sounds.controller.add(SoundAlert(SoundKind.name, at: DateTime(2026)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final label = find.text('Cineva te strigă');
    final entering = tester.getTopLeft(label).dy;
    await tester.pumpAndSettle();
    final settled = tester.getTopLeft(label).dy;
    expect(settled, lessThan(844 / 4));
    expect(entering, lessThan(settled));

    await tester.fling(label, const Offset(0, -300), 1500);
    await tester.pumpAndSettle();
    expect(label, findsNothing);
    h.alerts.dispose();
  });
}
