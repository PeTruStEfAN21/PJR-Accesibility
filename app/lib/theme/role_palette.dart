import 'package:flutter/material.dart';

import '../core/protocol.dart';
import '../settings/app_settings.dart';

/// Colours that tell the coordinator apart from the audience. Colour is never
/// the only cue: every caption also has an icon, a position and a text label.
///
/// Pairs are drawn from the Okabe–Ito colour-blind-safe set and adjusted per
/// condition so the two roles keep a clear lightness difference.
@immutable
class RolePalette extends ThemeExtension<RolePalette> {
  const RolePalette({required this.coordinator, required this.public});

  final Color coordinator;
  final Color public;

  Color of(Speaker speaker) => speaker == Speaker.coordinator ? coordinator : public;

  static const _light = {
    RolePaletteKind.standard: RolePalette(coordinator: Color(0xFF0060A8), public: Color(0xFFA34700)),
    RolePaletteKind.protanopia: RolePalette(coordinator: Color(0xFF0060A8), public: Color(0xFF6E5A00)),
    RolePaletteKind.deuteranopia: RolePalette(coordinator: Color(0xFF0060A8), public: Color(0xFF8A5A00)),
    RolePaletteKind.tritanopia: RolePalette(coordinator: Color(0xFFB0004F), public: Color(0xFF00707A)),
  };

  static const _dark = {
    RolePaletteKind.standard: RolePalette(coordinator: Color(0xFF6CB8FF), public: Color(0xFFFFA45C)),
    RolePaletteKind.protanopia: RolePalette(coordinator: Color(0xFF6CB8FF), public: Color(0xFFE8D24A)),
    RolePaletteKind.deuteranopia: RolePalette(coordinator: Color(0xFF6CB8FF), public: Color(0xFFF0C04A)),
    RolePaletteKind.tritanopia: RolePalette(coordinator: Color(0xFFFF7AAE), public: Color(0xFF4DD4DE)),
  };

  static RolePalette resolve(RolePaletteKind kind, Brightness brightness, {required bool highContrast}) {
    if (highContrast) {
      return brightness == Brightness.dark
          ? const RolePalette(coordinator: Color(0xFF9ED0FF), public: Color(0xFFFFD08A))
          : const RolePalette(coordinator: Color(0xFF003A70), public: Color(0xFF6B2E00));
    }
    return (brightness == Brightness.dark ? _dark : _light)[kind]!;
  }

  @override
  RolePalette copyWith({Color? coordinator, Color? public}) =>
      RolePalette(coordinator: coordinator ?? this.coordinator, public: public ?? this.public);

  @override
  RolePalette lerp(RolePalette? other, double t) => other == null
      ? this
      : RolePalette(
          coordinator: Color.lerp(coordinator, other.coordinator, t)!,
          public: Color.lerp(public, other.public, t)!,
        );
}

extension RolePaletteContext on BuildContext {
  RolePalette get roles => Theme.of(this).extension<RolePalette>()!;
}
