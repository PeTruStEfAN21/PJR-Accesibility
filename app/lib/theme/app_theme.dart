import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../settings/app_settings.dart';
import 'echo_style.dart';
import 'role_palette.dart';

const dyslexiaFont = 'OpenDyslexic';

/// The app's one typeface, bundled in assets/fonts.
const textFont = 'Roboto';

/// Echo has one theme, light, built from [EchoPalette] so screens that use the palette directly and
/// screens that use Material widgets look the same (docs/superpowers/specs/2026-10-23-redesign-design.md).
ThemeData buildTheme(AppSettings settings) {
  final p = settings.highContrast ? EchoPalette.highContrast : EchoPalette.standard;
  final scheme = ColorScheme.fromSeed(seedColor: p.accent).copyWith(
    primary: p.primary,
    onPrimary: p.onPrimary,
    primaryContainer: p.accentTint,
    onPrimaryContainer: p.text,
    secondary: p.accent,
    onSecondary: p.onPrimary,
    secondaryContainer: p.accentTint,
    onSecondaryContainer: p.text,
    surface: p.ground,
    onSurface: p.text,
    onSurfaceVariant: p.muted,
    surfaceContainerLowest: p.ground,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surface,
    surfaceContainerHighest: settings.highContrast ? p.ground : const Color(0xFFE5F3F4),
    outline: p.control,
    outlineVariant: p.border,
  );

  final base = ThemeData(colorScheme: scheme, useMaterial3: true, fontFamily: settings.dyslexiaMode ? dyslexiaFont : textFont);
  // Sizes are explicit: styles handed to component themes (the top bar, dialogs) are not given the
  // platform's sizes later, so a style without one would fall back to 14 px.
  final sized = base.textTheme.copyWith(
    headlineMedium: base.textTheme.headlineMedium?.copyWith(fontSize: 28, height: 1.25, fontWeight: FontWeight.w500, letterSpacing: -0.3),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(fontSize: 24, height: 1.3, fontWeight: FontWeight.w500, letterSpacing: -0.2),
    titleLarge: base.textTheme.titleLarge?.copyWith(fontSize: 22, height: 1.3, fontWeight: FontWeight.w600),
    titleMedium: base.textTheme.titleMedium?.copyWith(fontSize: 17, height: 1.4, fontWeight: FontWeight.w600),
    titleSmall: base.textTheme.titleSmall?.copyWith(fontSize: 15, height: 1.4, fontWeight: FontWeight.w600),
    labelMedium: base.textTheme.labelMedium?.copyWith(fontSize: 13, height: 1.3),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 17, height: 1.5),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.45),
    labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
  );
  final textTheme = (settings.dyslexiaMode
          // Wider letter and line spacing help readers with dyslexia follow fast captions.
          ? sized.apply(fontFamily: dyslexiaFont).copyWith(
              bodyLarge: sized.bodyLarge?.copyWith(fontFamily: dyslexiaFont, letterSpacing: 0.6, height: 1.8),
              bodyMedium: sized.bodyMedium?.copyWith(fontFamily: dyslexiaFont, letterSpacing: 0.5, height: 1.8),
              titleLarge: sized.titleLarge?.copyWith(fontFamily: dyslexiaFont, letterSpacing: 0.4, height: 1.6),
            )
          : sized)
      .apply(bodyColor: p.text, displayColor: p.text);

  final edge = settings.highContrast ? BorderSide(color: p.border, width: 2) : BorderSide(color: p.border);
  const pill = StadiumBorder();
  final focusRing = WidgetStateProperty.resolveWith<BorderSide?>(
      (states) => states.contains(WidgetState.focused) ? BorderSide(color: p.accent, width: 3) : null);

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: p.ground,
    // Minimum 48 px touch targets everywhere.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    // In the browser the default Cupertino slide paints a full-screen shadow on every frame and
    // stutters on Retina screens; a short fade is far cheaper. Phones keep their native transition.
    pageTransitionsTheme: kIsWeb ? _webTransitions : null,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: p.ground,
      foregroundColor: p.text,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: p.text),
      iconTheme: IconThemeData(color: p.text),
    ),
    cardTheme: CardThemeData(
      color: p.raised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: edge),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: pill,
        textStyle: textTheme.labelLarge,
      ).copyWith(side: focusRing),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 0,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: pill,
        textStyle: textTheme.labelLarge,
      ).copyWith(side: focusRing),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.accent,
        minimumSize: const Size(64, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: pill,
        side: BorderSide(color: p.control),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.accent, minimumSize: const Size(48, 48), textStyle: textTheme.labelLarge),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.primary,
      foregroundColor: p.onPrimary,
      elevation: 2,
      shape: const StadiumBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.raised,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: textTheme.bodyLarge?.copyWith(color: p.muted),
      floatingLabelStyle: textTheme.bodyLarge?.copyWith(color: p.accent, fontWeight: FontWeight.w600),
      hintStyle: textTheme.bodyLarge?.copyWith(color: p.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.control)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.control)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: p.accent, width: 2.5)),
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      iconColor: p.accent,
      textColor: p.text,
      subtitleTextStyle: textTheme.bodyMedium?.copyWith(color: p.muted),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onPrimary : p.control),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : p.surface),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.primary : p.control),
    ),
    checkboxTheme: CheckboxThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)), side: BorderSide(color: p.control, width: 2)),
    chipTheme: ChipThemeData(
      shape: StadiumBorder(side: BorderSide(color: p.border)),
      backgroundColor: p.raised,
      selectedColor: p.accentTint,
      labelStyle: textTheme.labelLarge?.copyWith(color: p.text),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 24),
    dialogTheme: DialogThemeData(
      backgroundColor: p.raised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: textTheme.titleLarge?.copyWith(color: p.text),
      contentTextStyle: textTheme.bodyLarge?.copyWith(color: p.text),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.raised,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.text,
      contentTextStyle: textTheme.bodyLarge?.copyWith(color: p.ground),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent, linearTrackColor: p.accentTint),
    sliderTheme: SliderThemeData(activeTrackColor: p.primary, thumbColor: p.primary, inactiveTrackColor: p.border),
    tabBarTheme: TabBarThemeData(labelColor: p.text, unselectedLabelColor: p.muted, indicatorColor: p.accent),
    extensions: [RolePalette.resolve(settings.palette, highContrast: settings.highContrast)],
  );
}

final _webTransitions = PageTransitionsTheme(
  builders: {for (final platform in TargetPlatform.values) platform: FadeUpwardsPageTransitionsBuilder()},
);
