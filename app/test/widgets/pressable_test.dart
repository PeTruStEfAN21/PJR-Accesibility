import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/widgets/pressable.dart';

Widget host({bool reduceMotion = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: Pressable(child: SizedBox.square(dimension: 100, child: ColoredBox(color: Color(0xFF000000))))),
      ),
    );

double scaleOf(WidgetTester tester) => tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

void main() {
  testWidgets('shrinks a little while pressed and comes back on release', (tester) async {
    await tester.pumpWidget(host());
    final gesture = await tester.startGesture(tester.getCenter(find.byType(SizedBox)));
    await tester.pump();
    expect(scaleOf(tester), Pressable.pressedScale);

    await gesture.up();
    await tester.pump();
    expect(scaleOf(tester), 1);
  });

  testWidgets('does not move when the system asks for reduced motion', (tester) async {
    await tester.pumpWidget(host(reduceMotion: true));
    expect(find.byType(AnimatedScale), findsNothing);
  });
}
