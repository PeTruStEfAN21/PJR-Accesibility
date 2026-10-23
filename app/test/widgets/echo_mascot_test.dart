import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/settings/app_settings.dart';
import 'package:pjr_accesibilitate/widgets/echo_mascot.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppSettings> _settings({bool highContrast = false}) async {
  SharedPreferences.setMockInitialValues({});
  return AppSettings(await SharedPreferences.getInstance())..highContrast = highContrast;
}

Widget _host(AppSettings settings, Widget child, {bool reduceMotion = false}) => SettingsScope(
      settings: settings,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );

void main() {
  testWidgets('every pose draws at its size, plays once and settles', (tester) async {
    final settings = await _settings();
    for (final pose in MascotPose.values) {
      await tester.pumpWidget(_host(settings, EchoMascot(pose, size: 80, key: ValueKey(pose))));
      expect(tester.getSize(find.byType(EchoMascot)), const Size(80, 80));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    }
  });

  testWidgets('screen readers skip it', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(await _settings(), const EchoMascot(MascotPose.hello)));
    await tester.pumpAndSettle();
    final node = tester.getSemantics(find.byType(EchoMascot));
    expect(node.label, isEmpty);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    handle.dispose();
  });

  testWidgets('a tap plays it again', (tester) async {
    await tester.pumpWidget(_host(await _settings(), const EchoMascot(MascotPose.alert)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(EchoMascot));
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('with reduced motion it shows the still pose and never moves', (tester) async {
    await tester.pumpWidget(_host(await _settings(), const EchoMascot(MascotPose.reading), reduceMotion: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    await tester.tap(find.byType(EchoMascot));
    await tester.pump(const Duration(seconds: 10));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('high contrast hides it', (tester) async {
    final settings = await _settings(highContrast: true);
    late bool shows;
    await tester.pumpWidget(_host(
      settings,
      Builder(builder: (context) {
        shows = EchoMascot.shows(context);
        return const EchoMascot(MascotPose.bravo);
      }),
    ));
    expect(shows, isFalse);
    expect(tester.getSize(find.byType(EchoMascot)), Size.zero);
  });

  testWidgets('it plays again when its tab comes back into view', (tester) async {
    final settings = await _settings();
    Widget tab(bool visible) => _host(settings, TickerMode(enabled: visible, child: const EchoMascot(MascotPose.hello)));
    await tester.pumpWidget(tab(true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(tab(false));
    await tester.pumpWidget(tab(true));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
  });
}
