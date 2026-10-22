import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/features/alerts/location_sounds.dart';
import 'package:pjr_accesibilitate/features/alerts/sound_alert.dart';
import 'package:pjr_accesibilitate/features/alerts/yamnet_logic.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('learned sounds are saved on the device and survive a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocationSoundStore(prefs);
    await store.add('Semnal linia 3', AlertLevel.warning, normalized([3, 4]));
    expect(store.sounds.single.label, 'Semnal linia 3');

    final reloaded = LocationSoundStore(prefs);
    final sound = reloaded.sounds.single;
    expect(sound.level, AlertLevel.warning);
    expect(sound.print[0], closeTo(0.6, 1e-6));
    expect(sound.print[1], closeTo(0.8, 1e-6));

    await reloaded.remove(sound.id);
    expect(LocationSoundStore(prefs).sounds, isEmpty);
  });

  test('a corrupt saved list does not break the app', () async {
    SharedPreferences.setMockInitialValues({'locationSounds': 'not json'});
    expect(LocationSoundStore(await SharedPreferences.getInstance()).sounds, isEmpty);
  });
}
