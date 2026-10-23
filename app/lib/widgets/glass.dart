import 'dart:ui';

import 'package:flutter/material.dart';

import '../settings/app_settings.dart';
import '../theme/echo_style.dart';

/// Echo's "liquid glass": a frosted, slightly translucent surface with a light top edge. It stays white
/// enough that text on it keeps its contrast whatever passes underneath; in high-contrast mode it is solid.
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
                  color: EchoPalette.shadow.withValues(alpha: 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: EchoPalette.shadow.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: shape,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withValues(alpha: 0.90), const Color(0xFFF1FAFC).withValues(alpha: 0.82)],
              ),
              // A light top edge and a faint cyan rim make the glass read as a raised layer.
              border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: shape,
                border: Border.all(
                  color: palette.border.withValues(alpha: 0.7),
                  strokeAlign: BorderSide.strokeAlignOutside,
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

/// The pill that marks the selected place on a glass control; it glides between places unless the
/// system asks for reduced motion.
class GlassPill extends StatelessWidget {
  const GlassPill({super.key, required this.index, required this.count, required this.height, required this.width});

  final int index;
  final int count;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    final palette = EchoPalette.of(context);
    final highContrast = SettingsScope.of(context).highContrast;
    final slot = width / count;
    return AnimatedPositioned(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      left: slot * index,
      top: 0,
      width: slot,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          gradient: highContrast
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [EchoPalette.pillTop, EchoPalette.pillBottom],
                ),
          color: highContrast ? palette.raised : null,
          border: Border.all(
            color: highContrast ? palette.border : Colors.white.withValues(alpha: 0.85),
            width: highContrast ? 2 : 1,
          ),
          boxShadow: highContrast
              ? null
              : [
                  BoxShadow(
                    color: EchoPalette.shadow.withValues(alpha: 0.14),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
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
