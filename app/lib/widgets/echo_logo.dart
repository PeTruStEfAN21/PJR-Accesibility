import 'package:flutter/material.dart';

import 'metal.dart';

/// The Echo mark: an ear whose outline runs on into lines of text, sound becoming captions.
///
/// Drawn from the team's SVG (400x400 viewBox): the same paths and stroke width, framed tightly
/// around the drawing and without the SVG's dark background, so it sits on the page. The strokes
/// are in Echo's polished metal ([Metal]), like the icons.
/// Decorative: the wordmark next to it is what screen readers announce.
class EchoLogo extends StatelessWidget {
  const EchoLogo({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(dimension: size, child: const CustomPaint(painter: _EchoMarkPainter())),
    );
  }
}

class _EchoMarkPainter extends CustomPainter {
  const _EchoMarkPainter();

  /// The square of the SVG's 400x400 box that holds the drawing, strokes included.
  static const _frame = Rect.fromLTWH(85, 70, 240, 240);
  static const _strokeWidth = 14.0;

  /// The SVG's shapes, as paths.
  static final List<Path> _shapes = [
    // The outer edge of the ear, running on into the first line of text.
    Path()
      ..moveTo(150, 260)
      ..cubicTo(120, 260, 100, 210, 115, 170)
      ..cubicTo(130, 120, 190, 115, 210, 145)
      ..cubicTo(218, 157, 225, 160, 240, 160)
      ..lineTo(290, 160),
    // The inner ear (the canal).
    Path()
      ..moveTo(140, 165)
      ..cubicTo(170, 155, 180, 190, 155, 205)
      ..cubicTo(145, 211, 140, 220, 145, 230),
    // The other lines of text, the middle one the longest.
    Path()
      ..moveTo(230, 195)
      ..lineTo(270, 195),
    Path()
      ..moveTo(205, 230)
      ..lineTo(310, 230),
    Path()
      ..moveTo(220, 265)
      ..lineTo(290, 265),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / _frame.width, size.height / _frame.height)
      ..translate(-_frame.left, -_frame.top);

    Paint stroke(double width) => Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final extrusion = stroke(_strokeWidth)..color = Metal.edge;
    final face = stroke(_strokeWidth)..shader = Metal.chrome.createShader(const Rect.fromLTRB(85, 110, 325, 280));
    final highlight = stroke(_strokeWidth * 0.3)..color = Metal.light;

    for (final path in _shapes) {
      canvas.drawPath(path.shift(const Offset(0, 6)), extrusion);
    }
    for (final path in _shapes) {
      canvas.drawPath(path, face);
    }
    for (final path in _shapes) {
      canvas.drawPath(path.shift(const Offset(-1, -3)), highlight);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EchoMarkPainter oldDelegate) => false;
}
