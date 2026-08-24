import 'dart:ui';

import 'package:flutter/material.dart';

/// Frosted "liquid glass" surface — blur + translucent fill + hairline border
/// with a top highlight, used for floating chrome (navbar, composer, sheets).
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
                  (tint ?? Colors.white).withValues(alpha: dark ? 0.08 : 0.72),
                  (tint ?? Colors.white).withValues(alpha: dark ? 0.035 : 0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.85),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.22 : 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
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
