import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/app_state.dart';
import '../widgets/bubble.dart';
import '../widgets/dragon_mark.dart';

/// Main chat surface.
///
/// Perf note: the transcript list rebuilds only when [AppState.bubbles]
/// changes. The in-flight streaming bubble hangs below the list and listens
/// to AppState.live directly, so token deltas never rebuild the list.
class ChatView extends StatefulWidget {
  final VoidCallback openMemories;
  const ChatView({super.key, required this.openMemories});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _scroll = ScrollController();
  var _showJump = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.hasClients && _scroll.offset < -40;
      if (show != _showJump) setState(() => _showJump = show);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final bubbles = state.bubbles;
    final approval = state.pendingApproval;

    return Stack(
      children: [
        if (bubbles.isEmpty)
          _EmptyState(openMemories: widget.openMemories)
        : GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Align(
              alignment: Alignment.topCenter,
              child: ListView.builder(
                reverse: true,
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                itemCount: bubbles.length,
                itemBuilder: (context, i) =>
                    MessageBubble(bubble: bubbles[bubbles.length - 1 - i]),
              ),
            ),
          ),
        if (_showJump && bubbles.isNotEmpty)
          Positioned(
            right: 18,
            bottom: 12,
            child: FloatingActionButton.small(
              heroTag: 'jump',
              onPressed: _jumpToBottom,
              backgroundColor: DragonColors.card,
              foregroundColor: Colors.white,
              elevation: 3,
              child: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ),
        // live bubble + approval card sit under the list, above the composer.
        // They animate independently and never trigger transcript rebuilds.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (approval != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ApprovalCard(request: approval)
                      .animate()
                      .fadeIn(duration: 250.ms)
                      .slideY(begin: 0.15, end: 0),
                ),
              ValueListenableBuilder<({String text, String thinking})?>(
                valueListenable: state.live,
                builder: (context, live, _) {
                  if (live == null) return const SizedBox.shrink();
                  return MessageBubble(
                    bubble: Bubble(
                      id: 'live',
                      kind: BubbleKind.assistant,
                      text: live.text,
                      thinking:
                          live.thinking.isEmpty ? null : live.thinking,
                      streaming: true,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback openMemories;
  const _EmptyState({required this.openMemories});

  static const _suggestions = [
    ('Explain hybrid memory like I\'m five', Icons.psychology_alt_rounded),
    ('Plan my week and remember my goals', Icons.event_note_rounded),
    ('Remember that my sister\'s name is Sara', Icons.auto_awesome_rounded),
    ('Summarise what you know about me', Icons.person_search_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const DragonAscii(fontSize: 7.2)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fade(begin: 0.65, end: 1.0, duration: 2200.ms),
            const SizedBox(height: 14),
            Text(
              'Dragon Agent',
              style: Theme.of(context).textTheme.headlineMedium!.copyWith(fontSize: 30),
            ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0),
            const SizedBox(height: 8),
            Text(
              'An AI that actually remembers you.\nFacts, rules & sessions — all on-device.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(height: 1.6, fontSize: 13.5),
            ).animate(delay: 150.ms).fadeIn(duration: 500.ms),
            const SizedBox(height: 26),
            ..._suggestions.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SuggestionChip(
                    label: e.value.$1,
                    icon: e.value.$2,
                    delay: (250 + e.key * 90).ms,
                  ),
                )),
            TextButton.icon(
              onPressed: openMemories,
              icon: Icon(Icons.memory_rounded, size: 17, color: DragonColors.gold),
              label: Text('Manage memories',
                  style: TextStyle(color: DragonColors.gold, fontSize: 13)),
            ).animate(delay: 700.ms).fadeIn(),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Duration delay;

  const _SuggestionChip({required this.label, required this.icon, required this.delay});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? DragonColors.card
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => state.send(label),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 17, color: DragonColors.ember),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_rounded,
                    size: 15, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25)),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: delay)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.25, end: 0, curve: Curves.easeOutCubic);
  }
}
