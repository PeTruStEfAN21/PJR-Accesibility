import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/widgets/echo_logo.dart';

void main() {
  testWidgets('the wordmark keeps its proportions and is read as its name', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: EchoLogo(height: 46, semanticLabel: 'Echo')),
    ));

    final size = tester.getSize(find.byType(EchoLogo));
    expect(size.height, 46);
    expect(size.width, closeTo(46 * 300 / 154, 0.01));
    expect(find.bySemanticsLabel('Echo'), findsOneWidget);
    handle.dispose();
  });
}
