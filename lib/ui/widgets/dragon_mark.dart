import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// The DRAGON AGENT wordmark as block ASCII — used as the in-app brand mark.
/// Rendered in platform monospace with an ember gradient and a soft fade-out
/// toward the bottom; the AGENT stanza sits slightly dimmer than DRAGON.
class DragonAscii extends StatelessWidget {
  final double fontSize;
  final bool softFade;

  const DragonAscii({super.key, this.fontSize = 7.5, this.softFade = true});

  static const _dragon = '''
██████╗ ██████╗  █████╗  ██████╗  ██████╗ ███╗   ██╗
██╔══██╗██╔══██╗██╔══██╗██╔════╝ ██╔═══██╗████╗  ██║
██║  ██║██████╔╝███████║██║  ███╗██║   ██║██╔██╗ ██║
██║  ██║██╔══██╗██╔══██║██║   ██║██║   ██║██║╚██╗██║
██████╔╝██║  ██║██║  ██║╚██████╔╝╚██████╔╝██║ ╚████║
╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝''';

  static const _agent = '''
 █████╗  ██████╗ ███████╗███╗   ██╗████████╗
██╔══██╗██╔════╝ ██╔════╝████╗  ██║╚══██╔══╝
███████║██║  ███╗█████╗  ██╔██╗ ██║   ██║
██╔══██║██║   ██║██╔══╝  ██║╚██╗██║   ██║
██║  ██║╚██████╔╝███████╗██║ ╚████║   ██║
╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═══╝   ╚═╝''';

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: fontSize,
      height: 1.06,
      letterSpacing: -fontSize * 0.02,
      color: Colors.white,
    );

    Widget stanza(String art, double opacity) => Opacity(
          opacity: opacity,
          child: Text(art, style: style, textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          )),
        );

    return ShaderMask(
      // vertical ember→gold melt over everything
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [DragonColors.gold, DragonColors.ember, DragonColors.emberDeep],
        stops: [0.0, 0.55, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: ShaderMask(
        // soft dissolve at the very bottom
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Colors.white,
            if (softFade) Colors.white.withValues(alpha: 0.25),
          ],
          stops: softFade ? const [0.0, 0.72, 1.0] : const [0.0, 1.0],
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            stanza(_dragon, 1.0),
            SizedBox(height: fontSize * 1.2),
            stanza(_agent, softFade ? 0.62 : 1.0),
          ],
        ),
      ),
    );
  }
}

/// Compact glass badge with the "DR" monogram — replaces the old flame glyph
/// wherever space is tight (navbar, drawer header, bubble avatars).
class DragonMonogram extends StatelessWidget {
  final double size;
  final bool plain;

  const DragonMonogram({super.key, this.size = 24, this.plain = false});

  @override
  Widget build(BuildContext context) {
    final glyph = ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [DragonColors.gold, DragonColors.ember],
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(
        'DR',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: size * 0.46,
          fontWeight: FontWeight.w900,
          letterSpacing: -size * 0.01,
          height: 1.0,
          color: Colors.white,
        ),
      ),
    );

    if (plain) return SizedBox(width: size, height: size, child: Center(child: glyph));

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DragonColors.ember.withValues(alpha: 0.22),
            DragonColors.emberDeep.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: DragonColors.ember.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: DragonColors.ember.withValues(alpha: 0.18),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: glyph,
    );
  }
}
