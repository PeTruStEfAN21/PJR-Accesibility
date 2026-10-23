import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pjr_accesibilitate/settings/app_settings.dart';
import 'package:pjr_accesibilitate/theme/app_theme.dart';
import 'package:pjr_accesibilitate/theme/echo_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WCAG contrast ratio between two opaque colors.
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

double max(double a, double b) => a > b ? a : b;
double min(double a, double b) => a < b ? a : b;

void main() {
  for (final (name, palette) in [('standard', EchoPalette.standard), ('high contrast', EchoPalette.highContrast)]) {
    group('$name palette', () {
      test('text and secondary text reach 7:1 on every background', () {
        for (final background in [palette.ground, palette.surface, palette.raised, palette.accentTint]) {
          expect(contrast(palette.text, background), greaterThanOrEqualTo(7), reason: 'text on $background');
          expect(contrast(palette.muted, background), greaterThanOrEqualTo(7), reason: 'muted on $background');
        }
      });

      test('buttons and links reach 7:1', () {
        expect(contrast(palette.onPrimary, palette.primary), greaterThanOrEqualTo(7));
        expect(contrast(palette.accent, palette.ground), greaterThanOrEqualTo(7));
        expect(contrast(palette.accent, palette.surface), greaterThanOrEqualTo(7));
      });

      test('icons and field borders stand out 3:1', () {
        expect(contrast(palette.brand, palette.ground), greaterThanOrEqualTo(3));
        expect(contrast(palette.brand, palette.accentTint), greaterThanOrEqualTo(3));
        expect(contrast(palette.control, palette.ground), greaterThanOrEqualTo(3));
      });
    });
  }

  for (final highContrast in [false, true]) {
    test('the Material theme follows the palette (high contrast: $highContrast)', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettings(await SharedPreferences.getInstance())..highContrast = highContrast;
      final scheme = buildTheme(settings).colorScheme;
      final palette = highContrast ? EchoPalette.highContrast : EchoPalette.standard;

      expect(scheme.primary, palette.primary);
      expect(contrast(scheme.onSurface, scheme.surface), greaterThanOrEqualTo(7));
      expect(contrast(scheme.onSurfaceVariant, scheme.surface), greaterThanOrEqualTo(7));
      expect(contrast(scheme.primary, scheme.surface), greaterThanOrEqualTo(7));
      expect(contrast(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(7));
      expect(contrast(scheme.onPrimaryContainer, scheme.primaryContainer), greaterThanOrEqualTo(7));
      expect(contrast(scheme.onSecondaryContainer, scheme.secondaryContainer), greaterThanOrEqualTo(7));
      for (final container in [scheme.surfaceContainerLow, scheme.surfaceContainer, scheme.surfaceContainerHighest]) {
        expect(contrast(scheme.onSurfaceVariant, container), greaterThanOrEqualTo(7));
      }
      expect(contrast(scheme.outline, scheme.surface), greaterThanOrEqualTo(3));
    });
  }

  test('styles given to the top bar and dialogs carry their own size, not the 14 px fallback', () async {
    SharedPreferences.setMockInitialValues({});
    final theme = buildTheme(AppSettings(await SharedPreferences.getInstance()));
    expect(theme.appBarTheme.titleTextStyle?.fontSize, greaterThanOrEqualTo(17));
    expect(theme.dialogTheme.titleTextStyle?.fontSize, greaterThanOrEqualTo(20));
    expect(theme.dialogTheme.contentTextStyle?.fontSize, greaterThanOrEqualTo(16));
  });
}
