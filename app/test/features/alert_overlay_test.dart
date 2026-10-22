import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/features/alerts/sound_alert.dart';

import '../fakes.dart';

void main() {
  testWidgets('a detected fire alarm covers any screen with the exit and needs acknowledging', (tester) async {
    final h = await TestHarness.create(prefs: {'uiLanguage': 'ro', 'emergencyExit': 'Scara B'});
    await tester.pumpWidget(h.app());
    await tester.tap(find.text('Sunt la un meeting'));
    await tester.pumpAndSettle();

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
    expect(find.text("I'm in a meeting"), findsOneWidget);
    h.alerts.dispose();
  });
}
