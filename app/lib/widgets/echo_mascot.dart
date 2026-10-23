import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../settings/app_settings.dart';
import '../theme/echo_style.dart';

/// The mascot's four poses (docs/specs/2026-10-23-mascota-design.md).
enum MascotPose {
  /// Both hands waving: the presenter's side of the Meeting tab.
  hello,

  /// Holding a page, eyes following the lines: nothing to read yet.
  reading,

  /// Wide eyes, a raised hand and an exclamation badge: the Vibrații screen.
  alert,

  /// Hands up, sparkles and a check mark: the presenter's voice has just been learned.
  bravo,

  /// Holding up an envelope with a gold dot, eyes on it, smiling: new announcements on the Dashboard.
  news,
}

/// Echo's mascot: a turquoise speech bubble with caption lines on its belly, drawn in code so every part
/// can move. Decoration only: screen readers skip it, high contrast hides it, and with reduced motion it
/// shows its final pose. It plays once when it appears (or its tab comes back), then only blinks; a tap
/// plays it again.
class EchoMascot extends StatefulWidget {
  const EchoMascot(this.pose, {super.key, this.size = 88, this.onTap});

  final MascotPose pose;
  final double size;

  /// Called on a tap, besides playing again (the Dashboard's mascot opens the announcements).
  final VoidCallback? onTap;

  /// False in high contrast, where the mascot is not drawn: callers drop the spacing around it too.
  static bool shows(BuildContext context) => !SettingsScope.of(context).highContrast;

  @override
  State<EchoMascot> createState() => _EchoMascotState();
}

class _EchoMascotState extends State<EchoMascot> with TickerProviderStateMixin {
  late final AnimationController _play = AnimationController(vsync: this, duration: _duration(widget.pose));
  late final AnimationController _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 170));
  final _random = math.Random();
  Timer? _nextBlink;
  bool _active = false;
  bool _still = false;

  static Duration _duration(MascotPose pose) => Duration(
        milliseconds: switch (pose) {
          MascotPose.hello => 1800,
          MascotPose.reading => 2600,
          MascotPose.alert => 1100,
          MascotPose.bravo => 1500,
          MascotPose.news => 1600,
        },
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    final active = TickerMode.valuesOf(context).enabled;
    if (_still) {
      _nextBlink?.cancel();
      _play.value = 1;
      _blink.value = 0;
    } else if (active && !_active) {
      // Appearing, or its tab coming back into view.
      _replay();
    }
    _active = active;
  }

  @override
  void didUpdateWidget(EchoMascot old) {
    super.didUpdateWidget(old);
    if (old.pose != widget.pose) {
      _play.duration = _duration(widget.pose);
      if (!_still) _replay();
    }
  }

  void _replay() {
    _play.forward(from: 0).whenCompleteOrCancel(_scheduleBlink);
  }

  void _scheduleBlink() {
    _nextBlink?.cancel();
    if (!mounted || _still || widget.pose == MascotPose.bravo) return;
    _nextBlink = Timer(Duration(milliseconds: 2800 + _random.nextInt(3200)), () {
      if (!mounted || !_active || _play.isAnimating) return;
      _blink.forward(from: 0).whenCompleteOrCancel(_scheduleBlink);
    });
  }

  @override
  void dispose() {
    _nextBlink?.cancel();
    _play.dispose();
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!EchoMascot.shows(context)) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: GestureDetector(
        onTap: () {
          if (!_still) _replay();
          widget.onTap?.call();
        },
        child: SizedBox.square(
          dimension: widget.size,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _MascotPainter(widget.pose, _play, _blink),
            ),
          ),
        ),
      ),
    );
  }
}

const _ink = Color(0xFF0C2225);
const _bodyTop = Color(0xFF80E6EC);
const _bodyMid = Color(0xFF38C6D1);
const _bodyBottom = EchoPalette.turquoise;
const _bodyShade = Color(0xFF0A8893);
const _handTop = Color(0xFF9FEEF3);
const _handBottom = Color(0xFF6DDAE3);
const _handLine = Color(0xFF129AA7);
const _cheek = Color(0xFFF3A9BB);
const _tongue = Color(0xFFF08CA3);
const _gold = Color(0xFFF8B832);
const _deepTeal = Color(0xFF0F5C64);
const _shadow = Color(0xFF0A4A50);

/// [t] mapped onto [begin, end], clamped, through [curve].
double _phase(double t, double begin, double end, [Curve curve = Curves.linear]) =>
    curve.transform(((t - begin) / (end - begin)).clamp(0.0, 1.0));

/// Draws the mascot in a 100 × 100 box. [play] runs the pose's motion from 0 to 1 and rests at 1, where
/// every pose is its still picture; [blink] closes the eyes on the way from 0 to 1 and back.
///
/// Proportions follow the team's drawing: the body is a squircle 56 wide, the eyes sit at 36% of its
/// height, the caption bars on the lower third; the hands are mittens with four fingers and a thumb on
/// the inner side; the tail leaves the bottom left.
class _MascotPainter extends CustomPainter {
  _MascotPainter(this.pose, this.play, this.blink) : super(repaint: Listenable.merge([play, blink]));

  final MascotPose pose;
  final Animation<double> play;
  final Animation<double> blink;

  static const _bodyRect = Rect.fromLTRB(22, 14, 78, 70);

  /// The body: a superellipse (exponent 3.6), flat-ish sides and large round corners.
  static final Path _body = _squircle(_bodyRect.center, 28, 28, 3.6);

  /// One hand, wrist at the origin, fingers up, thumb to the left (the right hand; mirrored for the left).
  static final Path _hand = _buildHand();

  static Path _squircle(Offset c, double rx, double ry, double n) {
    final path = Path();
    const steps = 96;
    for (var i = 0; i < steps; i++) {
      final a = 2 * math.pi * i / steps;
      final cs = math.cos(a), sn = math.sin(a);
      final x = c.dx + rx * cs.sign * math.pow(cs.abs(), 2 / n);
      final y = c.dy + ry * sn.sign * math.pow(sn.abs(), 2 / n);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  static Path _buildHand() {
    Path capsule(double w, double len, double x, double y, double tilt) {
      final m = Matrix4.identity()
        ..translateByDouble(x, y, 0, 1)
        ..rotateZ(tilt);
      return (Path()..addRRect(RRect.fromLTRBR(-w / 2, -len, w / 2, 1.5, Radius.circular(w / 2)))).transform(m.storage);
    }

    var shape = Path()
      ..addRRect(RRect.fromLTRBAndCorners(
        -7, -10, 7, 0,
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
        bottomLeft: const Radius.circular(5.5),
        bottomRight: const Radius.circular(5.5),
      ));
    // Fingers: index to pinky, the middle one longest, the outer ones leaning out a little.
    const fingers = [(-5.0, 7.2, -0.14), (-1.7, 8.6, -0.04), (1.7, 8.2, 0.04), (5.0, 6.6, 0.14)];
    for (final (x, len, tilt) in fingers) {
      shape = Path.combine(PathOperation.union, shape, capsule(3.4, len, x, -8.5, tilt));
    }
    // The thumb, on the inner side, leaning away from the palm.
    return Path.combine(PathOperation.union, shape, capsule(3.6, 7.4, -6.4, -3.6, -0.85));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = play.value;
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    // Every pose pops in a little, growing from where it stands.
    final pop = 0.88 + 0.12 * _phase(t, 0, 0.3, Curves.easeOutBack);
    var lift = 0.0;
    var shake = 0.0;
    if (pose == MascotPose.bravo) lift = -8 * math.sin(math.pi * _phase(t, 0, 0.45));
    if (pose == MascotPose.alert) {
      final u = _phase(t, 0.05, 0.6);
      shake = math.sin(u * math.pi * 6) * 2.2 * (1 - u);
    }

    _drawShadow(canvas, lift);
    canvas.save();
    canvas.translate(50 + shake, 91 + lift);
    canvas.scale(pop);
    canvas.translate(-50, -91);

    switch (pose) {
      case MascotPose.hello:
        final u = _phase(t, 0.1, 1);
        final wave = math.sin(u * math.pi * 6) * 0.3 * (1 - 0.55 * u);
        _drawBody(canvas, tail: true, captions: true);
        _eyes(canvas);
        _cheeks(canvas);
        _openSmile(canvas, wide: false);
        _waveLines(canvas, 0.45 + 0.55 * math.sin(u * math.pi * 6).abs());
        _drawHand(canvas, const Offset(21, 46), -0.35 - wave, mirror: true, scale: 1.2);
        _drawHand(canvas, const Offset(79, 46), 0.35 + wave, scale: 1.2);
      case MascotPose.reading:
        final u = _phase(t, 0.1, 0.92);
        final envelope = math.min(1.0, math.min(u * 8, (1 - u) * 8));
        final p = (u * 2) % 1;
        final dx = (p < 0.8 ? -2 + 4 * p / 0.8 : 2 - 4 * (p - 0.8) / 0.2) * envelope;
        final bob = math.sin(t * math.pi * 3) * 1.2 * (1 - t);
        _drawBody(canvas, tail: false, captions: false);
        _eyes(canvas, look: Offset(dx, 1.2));
        _cheeks(canvas);
        _smallSmile(canvas);
        canvas.save();
        canvas.translate(0, bob);
        _page(canvas);
        _drawHand(canvas, const Offset(36, 88), -0.2, mirror: true);
        _drawHand(canvas, const Offset(64, 88), 0.2);
        canvas.restore();
      case MascotPose.alert:
        final wave = math.sin(_phase(t, 0.3, 1) * math.pi * 4) * 0.25;
        _drawBody(canvas, tail: true, captions: true);
        _wideEyes(canvas);
        _cheeks(canvas);
        _ohMouth(canvas);
        _drawHand(canvas, const Offset(80, 45), 0.3 + wave, scale: 1.2);
        _badge(canvas, _phase(t, 0, 0.6, Curves.elasticOut));
      case MascotPose.bravo:
        final cheer = math.sin(_phase(t, 0, 0.6) * math.pi * 3) * 0.2;
        _drawBody(canvas, tail: true, captions: true);
        _happyEyes(canvas);
        _cheeks(canvas);
        _openSmile(canvas, wide: true);
        _drawHand(canvas, const Offset(26, 25), -0.5 - cheer, mirror: true, scale: 1.2);
        _drawHand(canvas, const Offset(74, 25), 0.5 + cheer, scale: 1.2);
        _sparkle(canvas, const Offset(9, 16), 4.5, _gold, _phase(t, 0.15, 0.5, Curves.easeOutBack));
        _sparkle(canvas, const Offset(91, 13), 3.6, _gold, _phase(t, 0.3, 0.65, Curves.easeOutBack));
        _sparkle(canvas, const Offset(92, 48), 2.6, _bodyBottom, _phase(t, 0.45, 0.8, Curves.easeOutBack));
        _check(canvas, _phase(t, 0.35, 0.75, Curves.easeOutBack));
      case MascotPose.news:
        // The envelope comes up, wiggles twice like a letter being shown, and its dot pops in.
        final rise = _phase(t, 0, 0.45, Curves.easeOutBack);
        final wiggle = math.sin(_phase(t, 0.35, 0.9) * math.pi * 4) * 0.12 * (1 - _phase(t, 0.35, 0.9));
        final wave = math.sin(_phase(t, 0.2, 1) * math.pi * 4) * 0.18;
        _drawBody(canvas, tail: true, captions: true);
        _eyes(canvas, look: const Offset(1.6, -1.2));
        _cheeks(canvas);
        _openSmile(canvas, wide: false);
        _drawHand(canvas, const Offset(22, 50), -0.4 - wave, mirror: true, scale: 1.1);
        canvas.save();
        canvas.translate(0, 10 * (1 - rise));
        _drawHand(canvas, const Offset(82, 43), 0.1, scale: 1.15);
        _envelope(canvas, 0.14 + wiggle, _phase(t, 0.45, 0.8, Curves.elasticOut));
        canvas.restore();
        _pings(canvas, _phase(t, 0.5, 1));
    }
    canvas.restore();
    canvas.restore();
  }

  void _drawShadow(Canvas canvas, double lift) {
    final shrink = 1 + lift / 24;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 91.5), width: 44 * shrink, height: 6 * shrink),
      Paint()
        ..color = _shadow.withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
  }

  void _drawBody(Canvas canvas, {required bool tail, required bool captions}) {
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_bodyTop, _bodyMid, _bodyBottom],
        stops: [0, 0.52, 1],
      ).createShader(_bodyRect);
    if (tail) {
      final tailPath = Path()
        ..moveTo(29, 63.5)
        ..quadraticBezierTo(27.5, 75, 22, 84)
        ..quadraticBezierTo(33, 77, 44.5, 68)
        ..close();
      canvas.drawPath(tailPath, fill);
    }
    canvas.drawPath(_body, fill);
    // A deeper shade along the bottom gives it volume.
    canvas.save();
    canvas.clipPath(_body);
    canvas.drawRect(
      const Rect.fromLTRB(22, 48, 78, 70),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bodyShade.withValues(alpha: 0), _bodyShade.withValues(alpha: 0.32)],
        ).createShader(const Rect.fromLTRB(22, 48, 78, 70)),
    );
    canvas.restore();
    // The glossy highlight, top left, and a small one beside it.
    canvas.save();
    canvas.translate(37, 23);
    canvas.rotate(-0.3);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 24, height: 8), Paint()..color = Colors.white.withValues(alpha: 0.5));
    canvas.restore();
    canvas.drawCircle(const Offset(53, 19.5), 1.9, Paint()..color = Colors.white.withValues(alpha: 0.5));
    if (captions) {
      // Two caption lines: pills with a faint shade under them and a touch of the body's colour at
      // their foot, so they sit on the belly instead of floating.
      for (final bar in [const Rect.fromLTRB(35, 52.2, 65, 55.4), const Rect.fromLTRB(40.5, 58.6, 59.5, 61.5)]) {
        final pill = RRect.fromRectAndRadius(bar, Radius.circular(bar.height / 2));
        canvas.drawRRect(pill.shift(const Offset(0, 0.7)), Paint()..color = _bodyShade.withValues(alpha: 0.28));
        canvas.drawRRect(
          pill,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, const Color(0xFFE4FAFB)],
            ).createShader(bar),
        );
      }
    }
  }

  double get _open => 1 - 0.9 * math.sin(math.pi * blink.value);

  void _eyes(Canvas canvas, {Offset look = Offset.zero}) {
    for (final x in const [40.0, 60.0]) {
      final c = Offset(x, 34.5) + look;
      canvas.drawOval(Rect.fromCenter(center: c, width: 9.6, height: 9.6 * _open), Paint()..color = _ink);
      if (_open > 0.5) {
        canvas.drawCircle(c + const Offset(-1.5, -1.6), 1.9, Paint()..color = Colors.white);
        canvas.drawCircle(c + const Offset(1.7, 1.5), 0.8, Paint()..color = Colors.white.withValues(alpha: 0.9));
      }
    }
  }

  /// Surprised, not scared: a thin ring of white around large pupils that look up at the badge, with
  /// the eyebrows raised.
  void _wideEyes(Canvas canvas) {
    final brow = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (final x in const [39.5, 60.5]) {
      final c = Offset(x, 34.5);
      final eye = Rect.fromCenter(center: c, width: 11.6, height: 11.6 * _open);
      canvas.drawOval(eye, Paint()..color = Colors.white);
      canvas.drawOval(eye, Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
      final pupil = c + Offset(-0.7, -0.9 * _open);
      canvas.drawOval(Rect.fromCenter(center: pupil, width: 8.2, height: 8.2 * _open), Paint()..color = _ink);
      if (_open > 0.5) {
        canvas.drawCircle(pupil + const Offset(-1.4, -1.5), 1.6, Paint()..color = Colors.white);
        canvas.drawCircle(pupil + const Offset(1.5, 1.4), 0.7, Paint()..color = Colors.white.withValues(alpha: 0.9));
      }
      canvas.drawPath(
        Path()
          ..moveTo(x - 4, 26.8)
          ..quadraticBezierTo(x, 23.8, x + 4, 26.2),
        brow,
      );
    }
  }

  void _happyEyes(Canvas canvas) {
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    for (final x in const [40.0, 60.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(x - 4.6, 37)
          ..quadraticBezierTo(x, 30, x + 4.6, 37),
        stroke,
      );
    }
  }

  void _cheeks(Canvas canvas) {
    final paint = Paint()..color = _cheek.withValues(alpha: 0.85);
    canvas.drawOval(Rect.fromCenter(center: const Offset(30.5, 41.5), width: 8, height: 5), paint);
    canvas.drawOval(Rect.fromCenter(center: const Offset(69.5, 41.5), width: 8, height: 5), paint);
  }

  /// A D-shaped open smile with the tongue showing; [wide] for the cheer.
  void _openSmile(Canvas canvas, {required bool wide}) {
    final half = wide ? 7.0 : 5.2;
    final depth = wide ? 8.0 : 6.4;
    final mouth = Path()
      ..moveTo(50 - half, 42.5)
      ..quadraticBezierTo(50, 44, 50 + half, 42.5)
      ..cubicTo(50 + half, 42.5 + depth, 50 - half, 42.5 + depth, 50 - half, 42.5)
      ..close();
    canvas.drawPath(mouth, Paint()..color = _ink);
    canvas.save();
    canvas.clipPath(mouth);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(50, 42.5 + depth * 0.95), width: half * 1.4, height: depth * 0.8),
      Paint()..color = _tongue,
    );
    canvas.restore();
  }

  void _smallSmile(Canvas canvas) {
    canvas.drawPath(
      Path()
        ..moveTo(46.5, 44)
        ..quadraticBezierTo(50, 47.8, 53.5, 44),
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  /// A small round „oh”, with the tongue showing.
  void _ohMouth(Canvas canvas) {
    final mouth = Rect.fromCenter(center: const Offset(50, 46), width: 5.6, height: 6.4);
    canvas.drawOval(mouth, Paint()..color = _ink);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(mouth, const Radius.circular(3.2)));
    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 49.2), width: 4.4, height: 3.6), Paint()..color = _tongue);
    canvas.restore();
  }

  /// The hand with its wrist at [wrist], pointing up and turned by [angle] (clockwise); [mirror] gives
  /// the left hand.
  void _drawHand(Canvas canvas, Offset wrist, double angle, {bool mirror = false, double scale = 1}) {
    canvas.save();
    canvas.translate(wrist.dx, wrist.dy);
    canvas.rotate(angle);
    canvas.scale(mirror ? -scale : scale, scale);
    canvas.drawPath(
      _hand,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_handTop, _handBottom],
        ).createShader(const Rect.fromLTRB(-9, -19, 9, 1.5)),
    );
    canvas.drawPath(
      _hand,
      Paint()
        ..color = _handLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round,
    );
    // The crease where the fingers meet the palm.
    canvas.drawPath(
      Path()
        ..moveTo(-5.6, -8.2)
        ..quadraticBezierTo(0, -10.2, 5.6, -8.2),
      Paint()
        ..color = _handLine.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  /// The arcs beside both waving hands, pulsing as they swing.
  void _waveLines(Canvas canvas, double opacity) {
    final paint = Paint()
      ..color = _bodyBottom.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final r in const [13.0, 16.5]) {
      canvas.drawArc(Rect.fromCircle(center: const Offset(18, 36), radius: r), math.pi - 0.4, 0.8, false, paint);
      canvas.drawArc(Rect.fromCircle(center: const Offset(82, 36), radius: r), -0.4, 0.8, false, paint);
    }
  }

  void _page(Canvas canvas) {
    final page = RRect.fromLTRBR(39.5, 52, 60.5, 82, const Radius.circular(3.5));
    canvas.drawRRect(page, Paint()..color = Colors.white);
    canvas.drawRRect(page, Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    final line = Paint()..color = _bodyBottom;
    canvas.drawRRect(RRect.fromLTRBR(43.5, 59, 56.5, 61.8, const Radius.circular(1.4)), line);
    canvas.drawRRect(RRect.fromLTRBR(43.5, 65, 54.5, 67.8, const Radius.circular(1.4)), line);
    canvas.drawRRect(RRect.fromLTRBR(43.5, 71, 51, 73.8, const Radius.circular(1.4)), Paint()..color = _deepTeal);
  }

  void _badge(Canvas canvas, double grow) {
    if (grow <= 0) return;
    canvas.save();
    canvas.translate(21, 15);
    canvas.scale(grow);
    canvas.drawCircle(Offset.zero, 8.2, Paint()..color = _gold);
    canvas.drawCircle(Offset.zero, 8.2, Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6);
    canvas.drawLine(const Offset(0, -4.4), const Offset(0, 1), Paint()
      ..color = _ink
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round);
    canvas.drawCircle(const Offset(0, 4.4), 1.5, Paint()..color = _ink);
    canvas.restore();
  }

  /// The envelope held up at the top right, turned by [angle], with a gold dot that grows by [dot].
  void _envelope(Canvas canvas, double angle, double dot) {
    canvas.save();
    canvas.translate(83, 19);
    canvas.rotate(angle);
    const card = Rect.fromLTRB(-13, -9, 13, 9);
    final outline = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    final rrect = RRect.fromRectAndRadius(card, const Radius.circular(2.6));
    canvas.drawRRect(rrect.shift(const Offset(0, 1)), Paint()..color = _shadow.withValues(alpha: 0.18));
    canvas.drawRRect(rrect, Paint()..color = Colors.white);
    // The flap and the two folds below it.
    canvas.drawPath(
      Path()
        ..moveTo(-12, -8)
        ..lineTo(0, 1.5)
        ..lineTo(12, -8),
      outline..color = _bodyBottom,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-12, 8)
        ..lineTo(-4, 0)
        ..moveTo(12, 8)
        ..lineTo(4, 0),
      Paint()
        ..color = _bodyBottom.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(rrect, outline..color = _ink);
    if (dot > 0) {
      canvas.save();
      canvas.translate(12, -9);
      canvas.scale(dot);
      canvas.drawCircle(Offset.zero, 4.6, Paint()..color = _gold);
      canvas.drawCircle(Offset.zero, 4.6, Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4);
      canvas.restore();
    }
    canvas.restore();
  }

  /// Short rays beside the envelope, fading in: it is new.
  void _pings(Canvas canvas, double grow) {
    if (grow <= 0) return;
    final paint = Paint()
      ..color = _gold.withValues(alpha: grow)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (final (from, to) in const [
      (Offset(67, 10), Offset(63.5, 6.5)),
      (Offset(65.5, 17), Offset(61, 16.5)),
      (Offset(98, 25), Offset(99.5, 29)),
    ]) {
      canvas.drawLine(from, Offset.lerp(from, to, grow)!, paint);
    }
  }

  /// A four-pointed star.
  void _sparkle(Canvas canvas, Offset c, double r, Color color, double grow) {
    if (grow <= 0) return;
    final s = r * grow;
    final star = Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s)
      ..close();
    canvas.drawPath(star, Paint()..color = color);
  }

  void _check(Canvas canvas, double grow) {
    if (grow <= 0) return;
    canvas.save();
    canvas.translate(81, 69);
    canvas.scale(grow);
    canvas.drawCircle(Offset.zero, 8.4, Paint()..color = _deepTeal);
    canvas.drawCircle(Offset.zero, 8.4, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2);
    canvas.drawPath(
      Path()
        ..moveTo(-4, 0.4)
        ..lineTo(-1.2, 3.4)
        ..lineTo(4.2, -3.2),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MascotPainter old) => old.pose != pose || old.play != play || old.blink != blink;
}
