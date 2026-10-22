import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/widgets/echo_logo.dart';

import '../fakes.dart';

void main() {
  testWidgets('the logo is drawn at its size and is decorative for screen readers', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: EchoLogo(size: 40)),
    ));

    expect(tester.getSize(find.byType(EchoLogo)), const Size(40, 40));
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
    handle.dispose();
  });

  testWidgets('the app opens in light mode unless the user picks otherwise', (tester) async {
    final h = await TestHarness.create();
    expect(h.settings.themeMode, ThemeMode.light);
  });
}
