import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import 'code_block.dart';
import 'dragon_mark.dart';

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
          thinking: bubble.thinking,
          usage: bubble.usage,
          streaming: bubble.streaming,
        );
      case BubbleKind.error:
        return _ErrorBubble(text: bubble.text ?? '');
      case BubbleKind.toolUse:
        return ToolChip(
          name: bubble.toolName ?? '',
          args: bubble.toolArgs,
          status: bubble.toolStatus,
          output: bubble.toolOutput,
        );
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
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.82),
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

class _AssistantBubble extends StatefulWidget {
  final String text;
  final String? thinking;
  final MsgUsage? usage;
  final bool streaming;
  const _AssistantBubble({
    required this.text,
    required this.streaming,
    this.thinking,
    this.usage,
  });

  @override
  State<_AssistantBubble> createState() => _AssistantBubbleState();
}

class _AssistantBubbleState extends State<_AssistantBubble> {
  var _thinkingOpen = false;

  // Markdown parse cache — rebuilding an identical widget instance lets
  // Flutter skip the subtree, so streaming ticks never re-parse old messages.
  Widget? _mdCache;
  String? _mdKey;

  Widget _markdown(BuildContext context) {
    final key =
        '${widget.text}\u0000${widget.streaming}\u0000${Theme.of(context).brightness}';
    if (_mdCache != null && _mdKey == key) return _mdCache!;
    _mdKey = key;
    _mdCache = MarkdownBody(
      data: widget.text.isEmpty && widget.streaming
          ? '▍'
          : '${widget.text}${widget.streaming ? ' ▍' : ''}',
      selectable: true,
      builders: {
        'pre': CodeBlockBuilder(),
      },
      styleSheet:
          MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: Theme.of(context)
            .textTheme
            .bodyMedium!
            .copyWith(fontSize: 15),
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
    );
    return _mdCache!;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasThinking =
        widget.thinking != null && widget.thinking!.trim().isNotEmpty;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(right: 48, top: 6, bottom: 6),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.86),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const DragonMonogram(size: 22, plain: true),
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
                if (widget.streaming) ...[
                  const SizedBox(width: 8),
                  _PulsingDot(),
                ],
                const Spacer(),
                if (widget.usage != null && !widget.streaming)
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.token_rounded,
                            size: 12,
                            color: scheme.onSurface.withValues(alpha: 0.4)),
                        const SizedBox(width: 3),
                        Text(
                          widget.usage!.short,
                          style: TextStyle(
                              fontSize: 10.5,
                              color: scheme.onSurface.withValues(alpha: 0.45)),
                        ),
                      ],
                    ),
                  ),
                if (!widget.streaming) _CopyButton(text: widget.text),
              ],
            ),
            const SizedBox(height: 5),
            if (hasThinking)
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 2),
                child: Material(
                  color: DragonColors.gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () =>
                        setState(() => _thinkingOpen = !_thinkingOpen),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 7),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.psychology_rounded,
                                  size: 14, color: DragonColors.gold),
                              const SizedBox(width: 7),
                              Text(
                                widget.streaming
                                    ? 'Thinking…'
                                    : 'Thought process',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: DragonColors.gold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              AnimatedRotation(
                                turns: _thinkingOpen ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.45)),
                              ),
                            ],
                          ),
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 200),
                            crossFadeState: _thinkingOpen
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            firstChild: const SizedBox(width: double.infinity),
                            secondChild: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                widget.thinking!,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.55,
                                  fontStyle: FontStyle.italic,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
              child: _markdown(context),
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
          ..showSnackBar(const SnackBar(
              content: Text('Copied to clipboard'),
              duration: Duration(milliseconds: 900)));
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
        border:
            Border.all(color: DragonColors.emberDeep.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              color: DragonColors.emberDeep, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 13.5, height: 1.4, color: DragonColors.emberDeep),
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
  final ToolStatus? status;
  final String? output;

  const ToolChip({
    super.key,
    required this.name,
    this.args,
    this.status,
    this.output,
  });

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

  String get prettyOutput {
    if (widget.output == null || widget.output!.isEmpty) return '';
    try {
      final decoded = jsonDecode(widget.output!);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return widget.output!;
    }
  }

  IconData get icon => switch (widget.name) {
        'save_memory' => Icons.auto_awesome_rounded,
        'forget_memory' => Icons.delete_sweep_outlined,
        'memory_write' => Icons.account_tree_rounded,
        'memory_read' => Icons.account_tree_outlined,
        'memory_delete' => Icons.delete_outline_rounded,
        'list_memories' => Icons.list_alt_rounded,
        'remember_rule' => Icons.rule_rounded,
        'datetime' => Icons.schedule_rounded,
        'calculator' => Icons.calculate_rounded,
        'device_info' => Icons.phone_android_rounded,
        'web_search' => Icons.travel_explore_rounded,
        _ => Icons.build_rounded,
      };

  (Color, String, IconData) get statusInfo {
    final dim =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    return switch (widget.status) {
      ToolStatus.running => (dim, 'running', Icons.hourglass_top_rounded),
      ToolStatus.denied => (
          DragonColors.emberDeep,
          'denied',
          Icons.block_rounded
        ),
      ToolStatus.error => (DragonColors.emberDeep, 'error', Icons.error_rounded),
      _ => (DragonColors.success, 'done', Icons.check_circle_rounded),
    };
  }

  @override
  Widget build(BuildContext context) {
    final dim = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    final (statusColor, statusLabel, statusIcon) = statusInfo;

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
                    const SizedBox(width: 8),
                    if (widget.status == ToolStatus.running)
                      const SizedBox(
                        width: 11,
                        height: 11,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.8, color: DragonColors.gold),
                      )
                    else ...[
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusLabel,
                          style: TextStyle(fontSize: 10.5, color: statusColor)),
                    ],
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          size: 17, color: dim),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 180),
                  crossFadeState:
                      open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (prettyArgs.isNotEmpty)
                          Text(
                            prettyArgs,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11.5,
                              height: 1.5,
                              color: dim,
                            ),
                          ),
                        if (prettyOutput.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '→ ${prettyOutput.length > 400 ? '${prettyOutput.substring(0, 400)}…' : prettyOutput}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              height: 1.5,
                              color: dim.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ],
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

// ------------------------------------------------------- approval card

/// Inline card asking the user to approve a sensitive tool call.
class ApprovalCard extends StatelessWidget {
  final ApprovalRequest request;
  const ApprovalCard({super.key, required this.request});

  String get prettyArgs {
    if (request.argsJson.isEmpty) return '';
    try {
      return const JsonEncoder.withIndent('  ')
          .convert(jsonDecode(request.argsJson));
    } catch (_) {
      return request.argsJson;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          DragonColors.gold.withValues(alpha: 0.10),
          DragonColors.ember.withValues(alpha: 0.07),
        ]),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: DragonColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_rounded, size: 18, color: DragonColors.gold),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Sensitive action — allow “${request.tool}”?',
                  style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (prettyArgs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              prettyArgs,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                height: 1.5,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ApprovalButton(
                  label: 'Deny',
                  icon: Icons.close_rounded,
                  onTap: () => context
                      .read<AppState>()
                      .resolveApproval(ApprovalDecision.deny),
                  emphasized: false,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ApprovalButton(
                  label: 'Always (session)',
                  icon: Icons.verified_user_rounded,
                  onTap: () => context
                      .read<AppState>()
                      .resolveApproval(ApprovalDecision.session),
                  emphasized: false,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ApprovalButton(
                  label: 'Allow once',
                  icon: Icons.check_rounded,
                  onTap: () => context
                      .read<AppState>()
                      .resolveApproval(ApprovalDecision.once),
                  emphasized: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovalButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool emphasized;

  const _ApprovalButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.emphasized,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized
          ? DragonColors.ember
          : Theme.of(context).brightness == Brightness.dark
              ? DragonColors.card
              : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          child: Column(
            children: [
              Icon(icon,
                  size: 16,
                  color: emphasized ? Colors.white : DragonColors.textDim),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: emphasized ? Colors.white : null,
                ),
              ),
            ],
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
                color:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
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
