import 'package:flutter/material.dart';

import '../settings/app_settings.dart';

/// Echo's screen colours ("editorial-greeting" tokens), with dark and high-contrast
/// variants. Used by the redesigned screens; the shared Material theme stays as it is.
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

  /// The logo's cyan, flat: for the few icons that carry the brand (main action, settings).
  final Color brand;

  /// The main action's panel: a pale tint of the accent.
  final Color accentTint;

  /// The one filled button: near-black, not the accent.
  final Color primary;
  final Color onPrimary;

  static EchoPalette of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (SettingsScope.of(context).highContrast) {
      final ink = dark ? Colors.white : Colors.black;
      final paper = dark ? Colors.black : Colors.white;
      return EchoPalette(
        ground: paper, surface: paper, raised: paper, border: ink, control: ink, text: ink, muted: ink,
        accent: ink, brand: ink, accentTint: paper, primary: ink, onPrimary: paper,
      );
    }
    return dark
        ? const EchoPalette(
            ground: Color(0xFF111111), surface: Color(0xFF1C1C1C), raised: Color(0xFF242424), border: Color(0xFF2E2E2E),
            control: Color(0xFF4A4A4A), text: Color(0xFFFFFFFF), muted: Color(0xFFB4B4B4), accent: Color(0xFF6CC2B6), brand: Color(0xFF4FD3E6),
            accentTint: Color(0xFF15302C), primary: Color(0xFFFFFFFF), onPrimary: Color(0xFF111111),
          )
        : const EchoPalette(
            ground: Color(0xFFFFFFFF), surface: Color(0xFFF9F9F9), raised: Color(0xFFFFFFFF), border: Color(0xFFEAEAEA),
            control: Color(0xFFB9BAB6), text: Color(0xFF1F201D), muted: Color(0xFF636361), accent: Color(0xFF1B6E66), brand: Color(0xFF007D90),
            accentTint: Color(0xFFE6F1EF), primary: Color(0xFF1F201D), onPrimary: Color(0xFFFFFFFF),
          );
  }
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
