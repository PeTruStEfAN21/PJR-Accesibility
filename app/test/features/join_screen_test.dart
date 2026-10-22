import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

Future<void> openJoin(WidgetTester tester, TestHarness h) async {
  await tester.pumpWidget(h.app());
  await tester.tap(find.text('Sunt la un meeting'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the server address is shown, not asked for, until the user wants to change it', (tester) async {
    final h = await TestHarness.create(prefs: {'uiLanguage': 'ro', 'serverUrl': 'http://172.20.10.2:8000'});
    await openJoin(tester, h);

    expect(find.text('http://172.20.10.2:8000'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);

    await tester.tap(find.text('Schimbă'));
    await tester.pump();
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('a broken server address says what is wrong', (tester) async {
    final h = await TestHarness.create();
    await openJoin(tester, h);

    await tester.enterText(find.byType(TextFormField), 'ABC234');
    await tester.tap(find.text('Schimbă'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).last, 'localhost');
    await tester.tap(find.text('Intră'));
    await tester.pumpAndSettle();
    expect(find.text('Adresa trebuie să înceapă cu http:// sau https://'), findsOneWidget);
  });
}
