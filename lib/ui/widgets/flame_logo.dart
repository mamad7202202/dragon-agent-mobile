import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Stylised dragon-flame glyph drawn with pure CustomPaint — crisp at any size.
class FlameLogo extends StatelessWidget {
  final double size;
  const FlameLogo({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FlamePainter()),
    );
  }
}

class _FlamePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // outer glow
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          DragonColors.ember.withValues(alpha: 0.35),
          DragonColors.ember.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCenter(center: Offset(w / 2, h / 2), width: w, height: h))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(w / 2, h * 0.55), w * 0.42, glow);

    // main flame
    final flamePath = Path()
      ..moveTo(w * 0.50, h * 0.06)
      ..cubicTo(w * 0.78, h * 0.30, w * 0.86, h * 0.52, w * 0.72, h * 0.74)
      ..cubicTo(w * 0.66, h * 0.86, w * 0.58, h * 0.94, w * 0.50, h * 0.97)
      ..cubicTo(w * 0.42, h * 0.94, w * 0.34, h * 0.86, w * 0.28, h * 0.74)
      ..cubicTo(w * 0.14, h * 0.52, w * 0.22, h * 0.30, w * 0.50, h * 0.06)
      ..close();

    final flame = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [DragonColors.gold, DragonColors.ember, DragonColors.emberDeep],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(flamePath, flame);

    // inner core
    final corePath = Path()
      ..moveTo(w * 0.50, h * 0.46)
      ..cubicTo(w * 0.62, h * 0.60, w * 0.64, h * 0.72, w * 0.56, h * 0.84)
      ..quadraticBezierTo(w * 0.53, h * 0.88, w * 0.50, h * 0.90)
      ..cubicTo(w * 0.47, h * 0.88, w * 0.44, h * 0.84, w * 0.44, h * 0.84)
      ..cubicTo(w * 0.36, h * 0.72, w * 0.38, h * 0.60, w * 0.50, h * 0.46)
      ..close();
    canvas.drawPath(
      corePath,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );

    // eye spark
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.34),
      w * 0.045,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );

    // wing strokes
    final wing = Paint()
      ..color = DragonColors.gold.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.13, h * 0.40), Offset(w * 0.02, h * 0.28), wing);
    canvas.drawLine(Offset(w * 0.87, h * 0.40), Offset(w * 0.98, h * 0.28), wing);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Subtle ember particles background for hero areas.
class EmberField extends StatefulWidget {
  final double height;
  const EmberField({super.key, this.height = 220});

  @override
  State<EmberField> createState() => _EmberFieldState();
}

class _EmberFieldState extends State<EmberField> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 7))
        ..repeat();

  static final _rng = math.Random(7);
  final particles = List.generate(26, (_) => _Particle.random(_rng));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => CustomPaint(
          painter: _EmberPainter(t: _ctrl.value, particles: particles),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Particle {
  final double x; // 0..1
  final double speed; // rise speed multiplier
  final double radius;
  final double phase;

  _Particle({
    required this.x,
    required this.speed,
    required this.radius,
    required this.phase,
  });

  factory _Particle.random(math.Random r) => _Particle(
        x: r.nextDouble(),
        speed: 0.4 + r.nextDouble() * 1.2,
        radius: 1 + r.nextDouble() * 2.6,
        phase: r.nextDouble(),
      );
}

class _EmberPainter extends CustomPainter {
  final double t;
  final List<_Particle> particles;
  _EmberPainter({required this.t, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final prog = ((t * p.speed + p.phase) % 1.0);
      final y = size.height * (1 - prog);
      final sway = math.sin(prog * math.pi * 3 + p.phase * 10) * 8;
      final opacity = prog < 0.15 ? prog / 0.15 : 1 - ((prog - 0.15) / 0.85);
      canvas.drawCircle(
        Offset(size.width * p.x + sway, y),
        p.radius,
        Paint()
          ..color = (p.radius > 2.6 ? DragonColors.gold : DragonColors.ember)
              .withValues(alpha: (opacity * 0.75).clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EmberPainter oldDelegate) =>
      oldDelegate.t != t;
}
