import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/llm.dart' show ProviderCfg;
import '../../state/app_state.dart';
import '../widgets/composer.dart';
import '../widgets/flame_logo.dart';
import '../widgets/glass.dart';
import '../widgets/update_banner.dart';
import 'chat_view.dart';
import 'memories_screen.dart';
import 'sessions_screen.dart';
import 'settings_screen.dart';
import 'skills_screen.dart';

/// App shell — floating glass nav bar over the chat surface.
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
    if (state.memoriesOpenTick != _memoriesTickSeen) {
      _memoriesTickSeen = state.memoriesOpenTick;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openMemories(context));
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _NavBar(state: state, openMemories: () => _openMemories(context)),
            UpdateBanner(),
            Expanded(child: ChatView(openMemories: () => _openMemories(context))),
            const Composer(),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// floating glass nav bar
// ------------------------------------------------------------------

class _NavBar extends StatelessWidget {
  final AppState state;
  final VoidCallback openMemories;
  const _NavBar({required this.state, required this.openMemories});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = state.busy;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: GlassContainer(
        radius: 22,
        blur: 22,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Row(
          children: [
            // model chip
            GestureDetector(
              onTap: () => showModelSheet(context),
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FlameLogo(size: 19),
                    const SizedBox(width: 9),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 148),
                      child: Text(
                        state.configured ? state.activeModel : 'not set up',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(Icons.expand_more_rounded,
                        size: 18, color: DragonColors.textDim),
                  ],
                ),
              ),
            ),
            const Spacer(),
            _NavBtn(
              icon: Icons.extension_rounded,
              tooltip: 'Skills · MCP',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SkillsScreen())),
            ),
            _NavBtn(
              icon: Icons.auto_awesome_rounded,
              tooltip: 'Memories',
              onTap: openMemories,
            ),
            _NavBtn(
              icon: Icons.forum_outlined,
              tooltip: 'Sessions',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SessionsScreen())),
            ),
            _NavBtn(
              icon: Icons.add_rounded,
              tooltip: 'New chat',
              emphasized: true,
              onTap: busy ? null : () => state.newSession(),
            ),
            _NavBtn(
              icon: Icons.tune_rounded,
              tooltip: 'Settings',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool emphasized;

  const _NavBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 42,
        height: 38,
        child: Material(
          color: emphasized ? DragonColors.ember : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: Icon(
              icon,
              size: 21,
              color: emphasized
                  ? Colors.white
                  : scheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
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
                        color:
                            m == active ? DragonColors.ember : DragonColors.textDim,
                      ),
                      title: Text(m, style: const TextStyle(fontSize: 13.5)),
                      onTap: () => Navigator.pop(context, m),
                    ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.edit_note_rounded,
                        size: 19, color: DragonColors.gold),
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
                            decoration: const InputDecoration(
                                hintText: 'provider/model-id'),
                          ),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel')),
                            FilledButton(
                                onPressed: () =>
                                    Navigator.pop(context, ctrl.text.trim()),
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
