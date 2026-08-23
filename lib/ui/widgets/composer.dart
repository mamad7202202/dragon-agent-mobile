import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../state/app_state.dart';

/// Bottom composer — rounded pill with an animated ember send button.
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
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? DragonColors.card
                : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: DragonColors.stroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(fontSize: 15, color: scheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Ask Dragon anything…',
                    filled: false,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
                            : (const LinearGradient(colors: [DragonColors.gold, DragonColors.ember])),
                        color: busy
                            ? scheme.onSurface.withValues(alpha: 0.08)
                            : null,
                      ),
                      child: IconButton(
                        onPressed: busy ? null : (_hasText ? _send : null),
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
      ),
    );
  }
}
