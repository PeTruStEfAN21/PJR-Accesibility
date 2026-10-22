import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/features/alerts/alert_controller.dart';
import 'package:pjr_accesibilitate/features/alerts/sound_alert.dart';

SoundAlert alert(SoundKind kind) => SoundAlert(kind, at: DateTime(2026));

void main() {
  test('a critical alert is not replaced by lower levels', () {
    final controller = AlertController(haptic: (_) {});
    controller.show(alert(SoundKind.fireAlarm));
    controller.show(alert(SoundKind.horn));
    controller.show(alert(SoundKind.name));
    expect(controller.current!.kind, SoundKind.fireAlarm);
    controller.dispose();
  });

  test('a critical alert replaces a warning', () {
    final controller = AlertController(haptic: (_) {});
    controller.show(alert(SoundKind.horn));
    controller.show(alert(SoundKind.siren));
    expect(controller.current!.kind, SoundKind.siren);
    controller.dispose();
  });

  test('critical alerts stay and keep vibrating until dismissed', () {
    fakeAsync((async) {
      final haptics = <Haptic>[];
      final controller = AlertController(haptic: haptics.add);
      controller.show(alert(SoundKind.fireAlarm));
      async.elapse(const Duration(minutes: 1));
      expect(controller.current, isNotNull);
      expect(haptics.length, greaterThan(100));

      controller.dismiss();
      final count = haptics.length;
      async.elapse(const Duration(seconds: 5));
      expect(controller.current, isNull);
      expect(haptics.length, count);
      controller.dispose();
    });
  });

  test('each level vibrates with the chosen vibration', () {
    final haptics = <Haptic>[];
    const chosen = {
      AlertLevel.critical: Haptic.light,
      AlertLevel.warning: Haptic.long,
      AlertLevel.info: Haptic.strong,
    };
    final controller = AlertController(haptic: haptics.add, hapticFor: (level) => chosen[level]!);
    controller.show(alert(SoundKind.horn));
    expect(haptics.first, Haptic.long);
    controller.dismiss();
    controller.show(alert(SoundKind.name));
    expect(haptics.last, Haptic.strong);
    controller.dispose();
  });

  test('critical repeats when the chosen pattern ends', () {
    fakeAsync((async) {
      final haptics = <Haptic>[];
      final controller = AlertController(haptic: haptics.add, hapticFor: (_) => Haptic.strong);
      controller.show(alert(SoundKind.fireAlarm));
      async.elapse(const Duration(milliseconds: 1549));
      expect(haptics.length, 1);
      async.elapse(const Duration(milliseconds: 2));
      expect(haptics.length, 2);
      async.elapse(const Duration(milliseconds: 1550));
      expect(haptics.length, 3);
      controller.dispose();
    });
  });

  test('a new choice applies from the next repeat', () {
    fakeAsync((async) {
      final haptics = <Haptic>[];
      var chosen = Haptic.long;
      final controller = AlertController(haptic: haptics.add, hapticFor: (_) => chosen);
      controller.show(alert(SoundKind.fireAlarm));
      chosen = Haptic.light;
      async.elapse(const Duration(milliseconds: 500));
      expect(haptics.last, Haptic.light);
      controller.dispose();
    });
  });

  test('warnings and info dismiss themselves', () {
    fakeAsync((async) {
      final controller = AlertController(haptic: (_) {});
      controller.show(alert(SoundKind.horn));
      async.elapse(AlertController.warningDuration);
      expect(controller.current, isNull);

      controller.show(alert(SoundKind.door));
      async.elapse(AlertController.infoDuration);
      expect(controller.current, isNull);
      controller.dispose();
    });
  });
}
