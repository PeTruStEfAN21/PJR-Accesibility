import 'package:flutter/material.dart';

/// The Echo wordmark: "echo" in lowercase, with the "e" sitting inside an ear.
///
/// Drawn from app/assets/brand/echo-logo.svg (viewBox 22 18 300 154): the same paths, stroke and
/// colour, so the app and the SVG stay identical. It replaces the written name, so screen readers
/// announce [semanticLabel].
class EchoLogo extends StatelessWidget {
  const EchoLogo({super.key, this.height = 46, required this.semanticLabel, this.color = brandColor});

  static const brandColor = Color(0xFF18B5D1);

  final double height;
  final String semanticLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: height * _EchoWordmarkPainter.frame.width / _EchoWordmarkPainter.frame.height,
        height: height,
        child: CustomPaint(painter: _EchoWordmarkPainter(color)),
      ),
    );
  }
}

class _EchoWordmarkPainter extends CustomPainter {
  const _EchoWordmarkPainter(this.color);

  final Color color;

  /// The SVG's viewBox.
  static const frame = Rect.fromLTWH(22, 18, 300, 154);

  /// The SVG's paths, in its own coordinates.
  static final List<Path> _shapes = [
    // The outer ear, from its top end round to the lobe.
    Path()
      ..moveTo(116, 56)
      ..cubicTo(118, 38, 102, 28, 82, 28)
      ..cubicTo(54, 28, 33, 48, 33, 72)
      ..cubicTo(33, 86, 38, 96, 44, 104)
      ..cubicTo(49, 111, 50, 118, 50, 126)
      ..cubicTo(50, 143, 55, 162, 74, 162)
      ..cubicTo(86, 162, 94, 153, 97, 144),
    // The inner ear.
    Path()
      ..moveTo(91, 59)
      ..cubicTo(85, 55, 80, 54, 74, 55)
      ..cubicTo(62, 57, 54, 67, 53, 81)
      ..cubicTo(52, 87, 53, 93, 55, 98),
    // The "e": its bar, its bowl, and the tail that runs into the "c".
    Path()
      ..moveTo(73.5, 101)
      ..lineTo(125, 101)
      ..cubicTo(125, 86, 113, 75, 99, 75)
      ..cubicTo(85, 75, 73, 88, 73, 103)
      ..cubicTo(73, 119, 85, 131, 99, 131)
      ..cubicTo(113, 131, 124, 125, 130, 116)
      ..cubicTo(134, 110, 137, 103, 137, 96),
    // The small notch under the "e".
    Path()
      ..moveTo(82, 124)
      ..lineTo(81, 133),
    // The "c", whose foot rises into the "h".
    Path()
      ..moveTo(177, 79)
      ..cubicTo(171, 74, 164, 72, 157, 72)
      ..cubicTo(145, 72, 137, 84, 137, 100)
      ..cubicTo(137, 118, 144, 129, 157, 129)
      ..cubicTo(172, 128, 184, 122, 192, 112),
    // The tall stem of the "h".
    Path()
      ..moveTo(196, 36)
      ..lineTo(196, 128),
    // The arch of the "h", down its right leg and up into the "o".
    Path()
      ..moveTo(196, 92)
      ..cubicTo(198, 79, 207, 71.4, 219, 71.4)
      ..cubicTo(231, 71.4, 240, 80, 240, 92)
      ..lineTo(240, 114)
      ..cubicTo(240, 123, 244, 127, 250, 127)
      ..cubicTo(256, 127, 260.5, 120, 260.5, 108),
    // The "o".
    Path()..addOval(Rect.fromCenter(center: const Offset(285.25, 99.4), width: 52.5, height: 56)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / frame.width, size.height / frame.height)
      ..translate(-frame.left, -frame.top);
    final stroke = Paint()
      ..isAntiAlias = true
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final shape in _shapes) {
      canvas.drawPath(shape, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EchoWordmarkPainter oldDelegate) => oldDelegate.color != color;
}
