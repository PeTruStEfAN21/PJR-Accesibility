import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../settings/app_settings.dart';
import 'role_palette.dart';

const dyslexiaFont = 'OpenDyslexic';

/// The app's one typeface, bundled in assets/fonts.
const textFont = 'Roboto';

ThemeData buildTheme(AppSettings settings, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  var scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2F6FDB), brightness: brightness);
  if (settings.highContrast) {
    scheme = scheme.copyWith(
      surface: dark ? Colors.black : Colors.white,
      onSurface: dark ? Colors.white : Colors.black,
      onSurfaceVariant: dark ? Colors.white : Colors.black,
      outline: dark ? Colors.white : Colors.black,
      primary: dark ? const Color(0xFFB8D4FF) : const Color(0xFF00337A),
      onPrimary: dark ? Colors.black : Colors.white,
    );
  }

  final base = ThemeData(colorScheme: scheme, useMaterial3: true, fontFamily: settings.dyslexiaMode ? dyslexiaFont : textFont);
  final textTheme = settings.dyslexiaMode
      // Wider letter and line spacing help readers with dyslexia follow fast captions.
      ? base.textTheme.apply(fontFamily: dyslexiaFont).copyWith(
            bodyLarge: base.textTheme.bodyLarge?.copyWith(fontFamily: dyslexiaFont, letterSpacing: 0.6, height: 1.8),
            bodyMedium: base.textTheme.bodyMedium?.copyWith(fontFamily: dyslexiaFont, letterSpacing: 0.5, height: 1.8),
            titleLarge: base.textTheme.titleLarge?.copyWith(fontFamily: dyslexiaFont, letterSpacing: 0.4, height: 1.6),
          )
      : base.textTheme;

  return base.copyWith(
    textTheme: textTheme,
    // Minimum 48 px touch targets everywhere.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    // In the browser the default Cupertino slide paints a full-screen shadow on every frame and
    // stutters on Retina screens; a short fade is far cheaper. Phones keep their native transition.
    pageTransitionsTheme: kIsWeb ? _webTransitions : null,
    visualDensity: VisualDensity.standard,
    extensions: [RolePalette.resolve(settings.palette, brightness, highContrast: settings.highContrast)],
  );
}

final _webTransitions = PageTransitionsTheme(
  builders: {for (final platform in TargetPlatform.values) platform: FadeUpwardsPageTransitionsBuilder()},
);
