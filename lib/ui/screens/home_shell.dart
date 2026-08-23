import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/llm.dart' show ProviderCfg;
import '../../state/app_state.dart';
import '../widgets/composer.dart';
import '../widgets/flame_logo.dart';
import 'chat_view.dart';
import 'memories_screen.dart';
import 'settings_screen.dart';

/// App shell — app bar with model picker, chat surface, memories & settings.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  var _memoriesTickSeen = -1;

  void _openMemories(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MemoriesScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 260),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // react to /memories command
    if (state.memoriesOpenTick != _memoriesTickSeen) {
      _memoriesTickSeen = state.memoriesOpenTick;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openMemories(context));
    }
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        toolbarHeight: 66,
        titleSpacing: 8,
        title: GestureDetector(
          onTap: () => showModelSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? DragonColors.card
                  : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: DragonColors.stroke),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FlameLogo(size: 18),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: Text(
                    state.configured ? state.activeModel : 'not set up',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface.withValues(alpha: 0.85)),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.expand_more_rounded, size: 17, color: DragonColors.textDim),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: state.busy ? null : () => state.newSession(),
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: kToolbarHeight + 14),
            Expanded(child: ChatView(openMemories: () => _openMemories(context))),
            const Composer(),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// model sheet
// ------------------------------------------------------------------

Future<void> showModelSheet(BuildContext context) async {
  final state = context.read<AppState>();
  final cfg = state.cfg;
  if (cfg == null) return;

  final result = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _ModelSheet(cfg: cfg, active: state.activeModel),
  );
  if (result != null && context.mounted) {
    await context.read<AppState>().setActiveModel(result);
  }
}

class _ModelSheet extends StatelessWidget {
  final ProviderCfg cfg;
  final String active;
  const _ModelSheet({required this.cfg, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? DragonColors.surface
            : Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: DragonColors.stroke),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: DragonColors.stroke,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text('Switch model',
                style: Theme.of(context).textTheme.titleMedium),
            Text('${cfg.name} · ${cfg.baseUrl}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall!
                    .copyWith(fontSize: 11.5)),
            const SizedBox(height: 14),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final m in cfg.models)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        m == active
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 19,
                        color: m == active ? DragonColors.ember : DragonColors.textDim,
                      ),
                      title: Text(m, style: const TextStyle(fontSize: 13.5)),
                      onTap: () => Navigator.pop(context, m),
                    ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.edit_note_rounded, size: 19, color: DragonColors.gold),
                    title: const Text('Use a custom model id…',
                        style: TextStyle(fontSize: 13.5)),
                    onTap: () async {
                      final ctrl = TextEditingController();
                      final custom = await showDialog<String>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Custom model'),
                          content: TextField(
                            controller: ctrl,
                            autofocus: true,
                            decoration:
                                const InputDecoration(hintText: 'provider/model-id'),
                          ),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel')),
                            FilledButton(
                                onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                                child: const Text('Use')),
                          ],
                        ),
                      );
                      if (custom != null && custom.isNotEmpty && context.mounted) {
                        Navigator.pop(context, custom);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
