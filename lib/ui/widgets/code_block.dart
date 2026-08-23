import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../../core/theme.dart';

/// Renders fenced code blocks as clean cards: language label, copy button,
/// horizontal scroll, monospace.
class CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    String code = element.textContent;
    if (code.endsWith('\n')) code = code.substring(0, code.length - 1);

    var language = '';
    final firstChild = element.children?.firstOrNull;
    if (firstChild is md.Element && firstChild.tag == 'code') {
      final cls = firstChild.attributes['class'] ?? '';
      if (cls.startsWith('language-')) {
        language = cls.substring('language-'.length);
      }
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    return _CodeCard(
      code: code,
      language: language,
      dark: dark,
    );
  }
}

class _CodeCard extends StatelessWidget {
  final String code;
  final String language;
  final bool dark;

  const _CodeCard({required this.code, required this.language, required this.dark});

  @override
  Widget build(BuildContext context) {
    final dim = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0E1015) : const Color(0xFF161922),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 14),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: DragonColors.emberGradient,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  language.isEmpty ? 'code' : language,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: dim,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 15,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(
                      content: Text('Code copied'),
                      duration: Duration(milliseconds: 900),
                    ));
                },
                icon: Icon(Icons.copy_rounded,
                    size: 15,
                    color: dim),
              ),
            ],
          ),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Text(
              code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.55,
                color: dark ? const Color(0xFFE8EAED) : const Color(0xFFE8EAED),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
