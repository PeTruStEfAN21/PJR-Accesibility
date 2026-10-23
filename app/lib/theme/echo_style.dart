import 'package:flutter/material.dart';

import '../settings/app_settings.dart';

/// Echo's colours, with a high-contrast variant: the one source for both Echo's own widgets and the
/// Material theme (`buildTheme`), so every screen looks the same.
class EchoPalette {
  const EchoPalette({
    required this.ground,
    required this.surface,
    required this.raised,
    required this.border,
    required this.control,
    required this.text,
    required this.muted,
    required this.accent,
    required this.brand,
    required this.accentTint,
    required this.primary,
    required this.onPrimary,
  });

  /// The page.
  final Color ground;

  /// Tonal panels, one step off the page.
  final Color surface;

  /// Row cards and fields inside a panel.
  final Color raised;
  final Color border;

  /// Field borders: one step stronger than [border].
  final Color control;
  final Color text;
  final Color muted;
  final Color accent;

  /// Icons that carry the brand (main actions, settings): a deeper shade of the turquoise, 3:1 or more.
  final Color brand;

  /// The main action's panel: a pale tint of the accent.
  final Color accentTint;

  /// The filled button: the deep turquoise, with white text.
  final Color primary;
  final Color onPrimary;

  /// The Deaf community's turquoise (the colour of sign language on the Deaf flag), on white. The bright
  /// turquoise is for the logo and decoration only; actions use a deep turquoise (7:1 on white), text is
  /// near-black, panels a very light turquoise.
  static const turquoise = Color(0xFF10A9B6);

  /// Card gradient, glass pill and soft shadows, all from the same turquoise family.
  static const cardTop = Color(0xFFE8F8F9);
  static const cardBottom = Color(0xFFD2EFF1);
  static const pillTop = Color(0xFFD6F2F4);
  static const pillBottom = Color(0xFFBEE8EC);
  static const shadow = Color(0xFF07393E);

  static const standard = EchoPalette(
    ground: Color(0xFFFFFFFF),
    surface: Color(0xFFF2FAFA),
    raised: Color(0xFFFFFFFF),
    border: Color(0xFFCFE8EA),
    control: Color(0xFF5B7B7F),
    text: Color(0xFF0A1A1C),
    muted: Color(0xFF32494C),
    accent: Color(0xFF005A63),
    brand: Color(0xFF00818F),
    accentTint: Color(0xFFDFF5F6),
    primary: Color(0xFF005A63),
    onPrimary: Color(0xFFFFFFFF),
  );

  static const highContrast = EchoPalette(
    ground: Colors.white,
    surface: Colors.white,
    raised: Colors.white,
    border: Colors.black,
    control: Colors.black,
    text: Colors.black,
    muted: Colors.black,
    accent: Colors.black,
    brand: Colors.black,
    accentTint: Colors.white,
    primary: Colors.black,
    onPrimary: Colors.white,
  );

  static EchoPalette of(BuildContext context) => SettingsScope.of(context).highContrast ? highContrast : standard;
}

/// The only two button styles on Echo's redesigned screens. Neither spreads a ripple: the filled
/// button darkens a little when pressed, the link underlines on hover, press and keyboard focus.
abstract final class EchoButtons {
  static ButtonStyle primary(EchoPalette p) => FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        shape: const StadiumBorder(),
        minimumSize: const Size(64, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        splashFactory: NoSplash.splashFactory,
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.pressed) || states.contains(WidgetState.hovered) ? p.onPrimary.withValues(alpha: 0.12) : null),
        side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused) ? BorderSide(color: p.accent, width: 3, strokeAlign: 2) : null),
      );

  static ButtonStyle link(EchoPalette p, {bool flush = false}) => TextButton.styleFrom(
        foregroundColor: p.text,
        minimumSize: const Size(48, 48),
        padding: flush ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 12),
        splashFactory: NoSplash.splashFactory,
      ).copyWith(
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        textStyle: WidgetStateProperty.resolveWith((states) {
          final active = states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.focused);
          return TextStyle(decoration: active ? TextDecoration.underline : TextDecoration.none, decorationThickness: 1.5);
        }),
      );
}
