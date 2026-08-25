import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/llm.dart' show ProviderCfg;
import '../../data/sessions.dart';
import '../../state/app_state.dart';
import '../widgets/composer.dart';
import '../widgets/dragon_mark.dart';
import '../widgets/glass.dart';
import '../widgets/update_banner.dart';
import 'chat_view.dart';
import 'integrations_screen.dart';
import 'memories_screen.dart';
import 'settings_screen.dart';
import 'skills_library_screen.dart';

/// App shell — minimal glass bar (menu · model · new) + sessions drawer.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  var _memoriesTickSeen = -1;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

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
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _openMemories(context));
    }
    _maybeShowUpdateDialog(state);

    return Scaffold(
      key: _scaffoldKey,
      drawer: const _AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _NavBar(
              onMenu: () => _scaffoldKey.currentState?.openDrawer(),
              onNew: state.busy ? null : () => state.newSession(),
            ),
            UpdateBanner(),
            Expanded(child: ChatView(openMemories: () => _openMemories(context))),
            const Composer(),
          ],
        ),
      ),
    );
  }

  void _maybeShowUpdateDialog(AppState state) {
    if (!state.shouldShowUpdateDialog) return;
    state.markUpdateDialogShown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Update available'),
          content: Text(
              'Version ${state.pendingUpdate!.version} is out — you are on '
              '${state.appVersion}. Updates install right over this one.'),
          actions: [
            TextButton(
              onPressed: () {
                state.skipUpdateVersion();
                Navigator.pop(dialogContext);
              },
              child: const Text("Don't show again"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Later'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: DragonColors.ember),
              onPressed: () {
                Navigator.pop(dialogContext);
                showUpdateSheet(context);
              },
              child: const Text('Update'),
            ),
          ],
        ),
      );
    });
  }
}

// ------------------------------------------------------------------
// minimal glass bar: menu · model · new
// ------------------------------------------------------------------

class _NavBar extends StatelessWidget {
  final VoidCallback? onNew;
  final VoidCallback onMenu;
  const _NavBar({required this.onMenu, required this.onNew});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: GlassRim(
        radius: 23,
        child: GlassContainer(
          radius: 22,
          blur: 34,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: Row(
            children: [
              _NavBtn(
                icon: Icons.menu_rounded,
                tooltip: 'Menu',
                onTap: onMenu,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => showModelSheet(context),
                  child: Container(
                    height: 38,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Row(
                      children: [
                        const DragonMonogram(size: 19),
                        const SizedBox(width: 9),
                        Expanded(
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
                        Icon(Icons.expand_more_rounded,
                            size: 18, color: DragonColors.textDim),
                      ],
                    ),
                  ),
                ),
              ),
              _NavBtn(
                icon: Icons.add_rounded,
                tooltip: 'New session',
                emphasized: true,
                onTap: onNew,
              ),
            ],
          ),
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
// drawer: quick actions + all sessions
// ------------------------------------------------------------------

class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final metas = state.sessions.metas;

    return Drawer(
      backgroundColor: dark ? DragonColors.surface : Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Row(
                children: [
                  const DragonMonogram(size: 30),
                  const SizedBox(width: 11),
                  Text('Dragon Agent',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  Text('v${state.appVersion}',
                      style: TextStyle(
                          fontSize: 11, color: DragonColors.textDim)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  _DrawerAction(
                    icon: Icons.extension_rounded,
                    label: 'Skills',
                    onTap: () => _push(context, const SkillsLibraryScreen()),
                  ),
                  _DrawerAction(
                    icon: Icons.link_rounded,
                    label: 'Connect',
                    onTap: () => _push(context, const IntegrationsScreen()),
                  ),
                  _DrawerAction(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Memory',
                    onTap: () {
                      Navigator.pop(context);
                      state.openMemories();
                    },
                  ),
                  _DrawerAction(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    onTap: () => _push(context, const SettingsScreen()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Divider(color: dark ? DragonColors.stroke : const Color(0x11000000)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
              child: Text('SESSIONS',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: DragonColors.textDim)),
            ),
            Expanded(
              child: metas.isEmpty
                  ? Center(
                      child: Text('No sessions yet — start one with +',
                          style: Theme.of(context).textTheme.bodySmall),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: metas.length,
                      itemBuilder: (context, i) =>
                          _SessionRow(meta: metas[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _DrawerAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DrawerAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Icon(icon, size: 20, color: DragonColors.gold),
              const SizedBox(height: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75))),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final SessionMeta meta;
  const _SessionRow({required this.meta});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final active = state.current?.id == meta.id;
    return Dismissible(
      key: ValueKey('drawer-${meta.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => state.deleteSession(meta.id),
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.only(right: 22),
        color: DragonColors.emberDeep.withValues(alpha: 0.12),
        child: const Icon(Icons.delete_outline_rounded,
            color: DragonColors.emberDeep),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18),
        dense: true,
        leading: Icon(
          Icons.chat_bubble_outline_rounded,
          size: 16,
          color: active ? DragonColors.ember : DragonColors.textDim,
        ),
        title: Text(
          meta.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? DragonColors.ember : null,
          ),
        ),
        subtitle: Text(_fmt(meta.updatedAt),
            style: TextStyle(fontSize: 11, color: DragonColors.textDim)),
        onTap: () async {
          Navigator.pop(context);
          await state.openSession(meta.id);
        },
      ),
    );
  }

  String _fmt(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${t.month}/${t.day}';
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
