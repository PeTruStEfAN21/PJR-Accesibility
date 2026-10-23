import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/features/presenter/enroll_view.dart';
import 'package:pjr_accesibilitate/l10n/app_localizations.dart';

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('ro'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('the speaker can stop the timer once done reading, and the voice is learned then', (tester) async {
    var recorded = 0;
    await tester.pumpWidget(_app(EnrollView(onRecorded: () async => recorded++)));
    await tester.ensureVisible(find.text('Începe'));
    await tester.tap(find.text('Începe'));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Te ascult… citește textul'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Am terminat de citit'));
    await tester.tap(find.byTooltip('Am terminat de citit'));
    await tester.pumpAndSettle();
    expect(recorded, 1);
    expect(find.text('Te ascult… citește textul'), findsNothing);

    // The stopped timer does not fire a second time.
    await tester.pump(const Duration(seconds: 30));
    expect(recorded, 1);
  });

  testWidgets('the Începe button sits in the middle', (tester) async {
    await tester.pumpWidget(_app(EnrollView(onRecorded: () async {})));
    final button = find.ancestor(of: find.text('Începe'), matching: find.byType(FilledButton));
    final screen = tester.getSize(find.byType(Scaffold));
    expect(tester.getCenter(button).dx, moreOrLessEquals(screen.width / 2, epsilon: 1));
  });
}
