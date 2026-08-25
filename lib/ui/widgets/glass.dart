import 'dart:ui';

import 'package:flutter/material.dart';

/// Real "liquid glass" surface.
///
/// Layers, back to front:
/// 1. backdrop blur + a touch of saturation (content melts behind the glass)
/// 2. translucent multi-stop fill, brighter toward the light (top-left)
/// 3. specular sheen sweeping from the top-left corner
/// 4. gradient hairline border — lit edge up top, fading to almost nothing
/// 5. soft ambient drop shadow so the pane floats
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? tint;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 24,
    this.radius = 24,
    this.padding,
    this.margin,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = tint ?? Colors.white;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.08),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: const Alignment(-0.3, 0.4),
                colors: [
                  Colors.white.withValues(alpha: dark ? 0.14 : 0.35),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.55],
              ),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  base.withValues(alpha: dark ? 0.10 : 0.66),
                  base.withValues(alpha: dark ? 0.05 : 0.48),
                  base.withValues(alpha: dark ? 0.08 : 0.56),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Gradient hairline drawn just outside [GlassContainer] content — a lit rim
/// that makes the pane read as thick glass rather than flat frosted card.
class GlassRim extends StatelessWidget {
  final Widget child;
  final double radius;

  const GlassRim({super.key, required this.child, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      foregroundPainter: _RimPainter(dark: dark, radius: radius),
      child: child,
    );
  }
}

class _RimPainter extends CustomPainter {
  final bool dark;
  final double radius;
  _RimPainter({required this.dark, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: dark ? 0.35 : 0.9),
            Colors.white.withValues(alpha: dark ? 0.06 : 0.25),
          ],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant _RimPainter old) => old.dark != dark;
}
