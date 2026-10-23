import 'dart:ui';

import 'package:flutter/material.dart';

import '../settings/app_settings.dart';
import '../theme/echo_style.dart';

/// Echo's liquid glass, after Apple's material (iOS 26): clear rather than frosted, the content beneath
/// stays visible and its colours are boosted (vibrancy), light catches the rim (a bright specular edge top
/// left, a second one bottom right) and a sheen sits inside the top edge, like thick glass. The tint stays
/// at about half white so text on it keeps its contrast whatever passes underneath; high contrast is solid.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = EdgeInsets.zero,
    this.shadow = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool shadow;

  /// Vibrancy: the backdrop's colours a little more saturated and a touch brighter, then a light blur.
  static final _vibrancy = ImageFilter.compose(
    outer: const ColorFilter.matrix(_saturateBrighten),
    inner: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
  );

  @override
  Widget build(BuildContext context) {
    final palette = EchoPalette.of(context);
    final shape = BorderRadius.circular(radius);
    if (SettingsScope.of(context).highContrast) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: palette.raised,
          borderRadius: shape,
          border: Border.all(color: palette.border, width: 2),
        ),
        child: Padding(padding: padding, child: child),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: EchoPalette.shadow.withValues(alpha: 0.14),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(color: EchoPalette.shadow.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1)),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: _vibrancy,
          child: CustomPaint(
            foregroundPainter: _SpecularRim(radius: radius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: shape,
                // Clear glass: about half white, a breath of turquoise, lighter at the top.
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.58),
                    Color.lerp(Colors.white, EchoPalette.turquoise, 0.06)!.withValues(alpha: 0.46),
                  ],
                ),
              ),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Saturation 1.6 and brightness +4%, as a colour matrix (Rec. 709 luma weights).
const _saturateBrighten = <double>[
  1.2758, -0.3576, -0.0362, 0, 10, //
  -0.0850, 1.0812, -0.0362, 0, 10, //
  -0.0850, -0.3576, 1.3626, 0, 10, //
  0, 0, 0, 1, 0, //
];

/// Light on the glass: a bright rim fading from the top-left corner, a fainter one bottom right, and a
/// soft sheen inside the top edge.
class _SpecularRim extends CustomPainter {
  const _SpecularRim({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(rect.deflate(0.75), Radius.circular(radius));
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.98),
          Colors.white.withValues(alpha: 0.30),
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.70),
        ],
        stops: const [0, 0.35, 0.65, 1],
      ).createShader(rect);
    canvas.drawRRect(shape, rim);

    // The sheen: light pooling just inside the top edge.
    final sheenRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.45);
    final sheen = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.38), Colors.white.withValues(alpha: 0)],
      ).createShader(sheenRect);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    canvas.drawRect(sheenRect, sheen);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SpecularRim oldDelegate) => oldDelegate.radius != radius;
}

/// The selection on glass: a clear droplet that glides between places (instantly with reduced motion),
/// with its own highlights and a stronger vibrancy lens on what it sits over.
class GlassPill extends StatelessWidget {
  const GlassPill({super.key, required this.index, required this.count, required this.height, required this.width});

  final int index;
  final int count;
  final double height;
  final double width;

  static final _lens = ImageFilter.compose(
    outer: const ColorFilter.matrix(_saturateBrighten),
    inner: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
  );

  @override
  Widget build(BuildContext context) {
    final palette = EchoPalette.of(context);
    final highContrast = SettingsScope.of(context).highContrast;
    final slot = width / count;
    final radius = height / 2;
    final shape = BorderRadius.circular(radius);
    return AnimatedPositioned(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      left: slot * index,
      top: 0,
      width: slot,
      height: height,
      child: highContrast
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: palette.raised,
                borderRadius: shape,
                border: Border.all(color: palette.border, width: 2),
              ),
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: shape,
                boxShadow: [
                  BoxShadow(
                    color: EchoPalette.turquoise.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: shape,
                child: BackdropFilter(
                  filter: _lens,
                  child: CustomPaint(
                    foregroundPainter: _SpecularRim(radius: radius),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: shape,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.55),
                            EchoPalette.pillTop.withValues(alpha: 0.70),
                            EchoPalette.pillBottom.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// A two-or-more way choice on glass, with the selection shown by the pill, a filled icon and bold text.
class GlassSegmented<T> extends StatelessWidget {
  const GlassSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.semanticLabel,
  });

  final List<(T value, IconData icon, IconData selectedIcon, String label)> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = EchoPalette.of(context);
    final theme = Theme.of(context);
    final index = options.indexWhere((o) => o.$1 == selected);
    return Semantics(
      container: true,
      label: semanticLabel,
      child: GlassSurface(
        radius: 30,
        padding: const EdgeInsets.all(5),
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              // The pill is as tall as the row; the row sets the height through its tallest option.
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, box) => Stack(
                    children: [
                      GlassPill(index: index, count: options.length, height: box.maxHeight, width: box.maxWidth),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (value, icon, selectedIcon, label) in options)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: value == selected,
                        label: label,
                        excludeSemantics: true,
                        child: InkWell(
                          onTap: () => onChanged(value),
                          borderRadius: BorderRadius.circular(26),
                          splashFactory: NoSplash.splashFactory,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 52),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    value == selected ? selectedIcon : icon,
                                    size: 22,
                                    color: value == selected ? palette.accent : palette.muted,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      label,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: value == selected ? palette.text : palette.muted,
                                        fontWeight: value == selected ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
