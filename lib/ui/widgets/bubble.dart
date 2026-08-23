import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import 'flame_logo.dart';

class MessageBubble extends StatelessWidget {
  final Bubble bubble;
  const MessageBubble({super.key, required this.bubble});

  @override
  Widget build(BuildContext context) {
    switch (bubble.kind) {
      case BubbleKind.user:
        return _UserBubble(text: bubble.text ?? '');
      case BubbleKind.assistant:
        return _AssistantBubble(
          text: bubble.text ?? '',
          streaming: bubble.streaming,
        );
      case BubbleKind.error:
        return _ErrorBubble(text: bubble.text ?? '');
      case BubbleKind.toolUse:
        return ToolChip(name: bubble.toolName ?? '', args: bubble.toolArgs);
      case BubbleKind.summary:
        return _SummaryChip(text: bubble.text ?? '');
    }
  }
}

// ---------------------------------------------------------------- user

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsets.only(left: 56, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          gradient: DragonColors.emberGradient,
          borderRadius: const BorderRadiusDirectional.only(
            topStart: Radius.circular(20),
            topEnd: Radius.circular(20),
            bottomStart: Radius.circular(20),
            bottomEnd: Radius.circular(6),
          ),
          boxShadow: [
            BoxShadow(
              color: DragonColors.ember.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- assistant

class _AssistantBubble extends StatelessWidget {
  final String text;
  final bool streaming;
  const _AssistantBubble({required this.text, required this.streaming});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(right: 48, top: 6, bottom: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FlameLogo(size: 22),
                const SizedBox(width: 7),
                Text(
                  'Dragon',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface.withValues(alpha: 0.55),
                    letterSpacing: 0.3,
                  ),
                ),
                if (streaming) ...[
                  const SizedBox(width: 8),
                  _PulsingDot(),
                ],
                const Spacer(),
                if (!streaming)
                  _CopyButton(text: text),
              ],
            ),
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border.all(color: DragonColors.stroke),
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(6),
                  topEnd: Radius.circular(20),
                  bottomStart: Radius.circular(20),
                  bottomEnd: Radius.circular(20),
                ),
              ),
              child: MarkdownBody(
                data: text.isEmpty && streaming ? '▍' : '$text${streaming ? ' ▍' : ''}',
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 15),
                  codeblockDecoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF101218)
                        : const Color(0xFFF3F1EE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DragonColors.stroke),
                  ),
                  blockquoteDecoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: DragonColors.ember, width: 3),
                    ),
                    color: DragonColors.ember.withValues(alpha: 0.06),
                  ),
                  horizontalRuleDecoration: BoxDecoration(
                    border: Border(top: BorderSide(color: DragonColors.stroke)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  final String text;
  const _CopyButton({required this.text});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      iconSize: 16,
      onPressed: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Copied to clipboard'), duration: Duration(milliseconds: 900)));
      },
      icon: Icon(Icons.copy_rounded,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45)),
    );
  }
}

// ---------------------------------------------------------------- error

class _ErrorBubble extends StatelessWidget {
  final String text;
  const _ErrorBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DragonColors.emberDeep.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DragonColors.emberDeep.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: DragonColors.emberDeep, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13.5, height: 1.4, color: DragonColors.emberDeep),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- tool

class ToolChip extends StatefulWidget {
  final String name;
  final String? args;
  const ToolChip({super.key, required this.name, this.args});

  @override
  State<ToolChip> createState() => _ToolChipState();
}

class _ToolChipState extends State<ToolChip> {
  bool open = false;

  String get prettyArgs {
    if (widget.args == null || widget.args!.isEmpty) return '';
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(widget.args!));
    } catch (_) {
      return widget.args!;
    }
  }

  IconData get icon => switch (widget.name) {
        'save_memory' => Icons.auto_awesome_rounded,
        'forget_memory' => Icons.delete_sweep_outlined,
        _ => Icons.build_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final dim = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: DragonColors.ember.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => open = !open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15, color: DragonColors.gold),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: dim,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: dim),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 180),
                  crossFadeState: open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      prettyArgs,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        height: 1.5,
                        color: dim,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String text;
  const _SummaryChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: DragonColors.stroke,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.compress_rounded, size: 13, color: DragonColors.gold),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    lowerBound: 0,
    upperBound: 1,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.25, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: DragonColors.emberGradient,
        ),
      ),
    );
  }
}
