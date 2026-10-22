import 'package:flutter/material.dart';

/// Echo's polished-metal look, used by the logo only: a deep cyan chrome face, a darker
/// extrusion below it and a thin light edge above it.
abstract final class Metal {
  /// Chrome bands from top to bottom: a bright reflection, cyan, a dark band, then cyan again.
  static const chrome = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF7FE6F2), Color(0xFF00A9C2), Color(0xFF005A69), Color(0xFF1597AB), Color(0xFF007D90)],
    stops: [0.0, 0.3, 0.55, 0.75, 1.0],
  );

  /// The metal's side, seen below each shape.
  static const edge = Color(0xFF00363F);

  /// The light catching the top edge.
  static final light = Colors.white.withValues(alpha: 0.65);
}
