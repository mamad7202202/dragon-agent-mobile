import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../services/skills.dart';
import '../../state/app_state.dart';
import 'glass.dart';

class _Suggestion {
  final String title;
  final String subtitle;
  final String insert; // text to insert (commands) — empty for skills
  final LoadedSkill? skill;
  final bool isSkill;

  const _Suggestion.command(this.title, this.subtitle, this.insert)
      : skill = null,
        isSkill = false;
  _Suggestion.skill(LoadedSkill s)
      : title = s.name,
        subtitle = 'skill · ${s.repo}',
        skill = s,
        isSkill = true,
        insert = '';
}

const _commands = <_Suggestion>[
  _Suggestion.command('/new', 'start a fresh session', '/new'),
  _Suggestion.command('/remember', 'pin a long-term fact', '/remember '),
  _Suggestion.command('/forget', 'delete a fact by id', '/forget '),
  _Suggestion.command('/memories', 'open memory manager', '/memories'),
  _Suggestion.command('/clear', 'wipe all facts', '/clear'),
  _Suggestion.command('/help', 'list commands', '/help'),
];

/// Floating glass composer with a "/" suggestion picker (commands + skills).
class Composer extends StatefulWidget {
  const Composer({super.key});

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      final has = _ctrl.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<_Suggestion> get _suggestions {
    final text = _ctrl.text;
    if (!text.startsWith('/')) return const [];
    final q = text.substring(1).toLowerCase();
    final state = context.read<AppState>();
    final out = <_Suggestion>[
      ..._commands.where((c) => q.isEmpty || c.title.substring(1).startsWith(q)),
      ...state.skills.all
          .where((s) =>
              q.isEmpty ||
              s.name.toLowerCase().contains(q) ||
              s.description.toLowerCase().contains(q))
          .map(_Suggestion.skill),
    ];
    return out.take(6).toList();
  }

  void _apply(_Suggestion s) {
    final state = context.read<AppState>();
    if (s.isSkill) {
      state.setActiveSkill(s.skill);
      _ctrl.clear();
      HapticFeedback.selectionClick();
    } else {
      _ctrl.text = s.insert;
      _ctrl.selection = TextSelection.collapsed(offset: s.insert.length);
    }
    _focus.requestFocus();
  }

  void _send() {
    final state = context.read<AppState>();
    if (!state.configured || state.busy) return;
    final text = _ctrl.text;
    _ctrl.clear();
    HapticFeedback.lightImpact();
    state.send(text);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.select<AppState, bool>((s) => s.busy);
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final suggestions = _suggestions;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
        child: GlassRim(
          radius: 27,
          child: GlassContainer(
            radius: 26,
            blur: 36,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // active skill chip
              if (state.activeSkill != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: DragonColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: DragonColors.gold.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_fix_high_rounded,
                            size: 14, color: DragonColors.gold),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            state.activeSkill!.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: DragonColors.gold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => state.setActiveSkill(null),
                          child: Icon(Icons.close_rounded,
                              size: 14,
                              color: DragonColors.gold.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                ),
              // "/" suggestions
              if (suggestions.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    itemCount: suggestions.length,
                    itemBuilder: (context, i) {
                      final s = suggestions[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _apply(s),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          child: Row(
                            children: [
                              Icon(
                                s.isSkill
                                    ? Icons.auto_fix_high_rounded
                                    : Icons.chevron_right_rounded,
                                size: 15,
                                color: s.isSkill
                                    ? DragonColors.gold
                                    : DragonColors.textDim,
                              ),
                              const SizedBox(width: 9),
                              Text(s.title,
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(s.subtitle,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: DragonColors.textDim)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: scheme.onSurface,
                            decoration: TextDecoration.none),
                        decoration: InputDecoration(
                          hintText: state.activeSkill != null
                              ? 'Message with ${state.activeSkill!.name}…'
                              : 'Message Dragon — / for skills',
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: AnimatedScale(
                        scale: (_hasText || busy) ? 1 : 0.92,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeOutBack,
                        child: SizedBox(
                          width: 42,
                          height: 42,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: busy
                                  ? null
                                  : (const LinearGradient(colors: [
                                      DragonColors.gold,
                                      DragonColors.ember
                                    ])),
                              color: busy
                                  ? scheme.onSurface.withValues(alpha: 0.08)
                                  : null,
                            ),
                            child: IconButton(
                              onPressed:
                                  busy ? null : (_hasText ? _send : null),
                              icon: busy
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: DragonColors.ember,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_upward_rounded,
                                      color: Colors.white, size: 21),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
