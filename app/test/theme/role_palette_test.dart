import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/settings/app_settings.dart';
import 'package:pjr_accesibilitate/theme/role_palette.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pjr_accesibilitate/theme/app_theme.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings(await SharedPreferences.getInstance());

  // Role labels are drawn in the role colour on the caption background, so
  // they need WCAG AA text contrast (4.5:1) in every palette.
  for (final highContrast in [false, true]) {
    for (final kind in RolePaletteKind.values) {
      test('$kind highContrast=$highContrast meets AA', () {
        settings.update((s) {
          s.palette = kind;
          s.highContrast = highContrast;
        });
        final theme = buildTheme(settings);
        final roles = theme.extension<RolePalette>()!;
        final background = theme.colorScheme.surfaceContainerHighest;
        expect(contrast(roles.coordinator, background), greaterThanOrEqualTo(4.5));
        expect(contrast(roles.public, background), greaterThanOrEqualTo(4.5));
        expect(roles.coordinator, isNot(roles.public));
      });
    }
  }
}
