import 'dart:ui';

import 'package:flutter/material.dart';

/// Frosted "liquid glass" surface — blur + translucent fill + hairline border
/// with a top highlight, used for floating chrome (composer, chips, sheets).
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
    this.blur = 18,
    this.radius = 24,
    this.padding,
    this.margin,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (tint ?? (dark ? Colors.white : Colors.white))
                      .withValues(alpha: dark ? 0.09 : 0.72),
                  (tint ?? (dark ? Colors.white : Colors.white))
                      .withValues(alpha: dark ? 0.04 : 0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.85),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.35 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Gradient fade that sits behind the composer — black in dark mode,
/// white in light mode — strongest at the bottom, vanishing upwards.
class BottomFade extends StatelessWidget {
  final double height;
  const BottomFade({super.key, this.height = 150});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? Colors.black : Colors.white;
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.55, 1.0],
            colors: [
              base.withValues(alpha: 0.0),
              base.withValues(alpha: 0.55),
              base.withValues(alpha: 0.94),
            ],
          ),
        ),
      ),
    );
  }
}
