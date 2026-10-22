import 'package:flutter/material.dart';

/// Shrinks its child slightly while pressed, so a tap feels heard (Emil Kowalski's 0.97 rule).
/// No motion when the system asks for reduced motion.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child});

  final Widget child;

  /// A strong ease-out: the press shows at once instead of easing in.
  static const curve = Cubic(0.23, 1, 0.32, 1);
  static const pressedScale = 0.97;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? Pressable.pressedScale : 1,
        duration: const Duration(milliseconds: 160),
        curve: Pressable.curve,
        child: widget.child,
      ),
    );
  }
}
