import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/features/alerts/alert_controller.dart';
import 'package:pjr_accesibilitate/features/alerts/sound_alert.dart';
import 'package:pjr_accesibilitate/settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppSettings> _settings([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(prefs);
  return AppSettings(await SharedPreferences.getInstance());
}

void main() {
  test("defaults are today's vibrations", () async {
    final s = await _settings();
    expect(s.hapticFor(AlertLevel.critical), Haptic.long);
    expect(s.hapticFor(AlertLevel.warning), Haptic.strong);
    expect(s.hapticFor(AlertLevel.info), Haptic.light);
  });

  test("choosing another level's vibration swaps the two", () async {
    final s = await _settings();
    expect(s.chooseHaptic(AlertLevel.info, Haptic.long), AlertLevel.critical);
    expect(s.hapticFor(AlertLevel.info), Haptic.long);
    expect(s.hapticFor(AlertLevel.critical), Haptic.light);
  });

  test('choosing the current vibration changes nothing', () async {
    final s = await _settings();
    expect(s.chooseHaptic(AlertLevel.warning, Haptic.strong), isNull);
    expect(s.alertHaptics, AppSettings.defaultAlertHaptics);
  });

  test('the choice survives a restart', () async {
    final s = await _settings();
    s.chooseHaptic(AlertLevel.info, Haptic.long);
    final again = AppSettings(await SharedPreferences.getInstance());
    expect(again.hapticFor(AlertLevel.info), Haptic.long);
    expect(again.hapticFor(AlertLevel.critical), Haptic.light);
    expect(again.hapticFor(AlertLevel.warning), Haptic.strong);
  });

  test('a broken save falls back to the defaults', () async {
    for (final bad in [
      '{"critical":"light","warning":"light","info":"long"}',
      'nu e json',
      '{"critical":"buzz"}',
    ]) {
      final s = await _settings({'alertHaptics': bad});
      expect(s.alertHaptics, AppSettings.defaultAlertHaptics, reason: bad);
    }
  });
}
