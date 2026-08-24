import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme.dart';
import '../../services/mcp.dart';
import '../../state/app_state.dart';
import '../widgets/flame_logo.dart';

/// Skills — MCP servers the dragon can call tools from.
class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final mcp = state.mcp;

    return Scaffold(
      appBar: AppBar(title: const Text('Skills · MCP')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-skill',
        onPressed: () => _addServerSheet(context),
        backgroundColor: DragonColors.ember,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add skill'),
      ),
      body: RefreshIndicator(
        color: DragonColors.ember,
        onRefresh: () => mcp.refreshAll(),
        child: mcp.servers.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 90),
                  Center(
                    child: Column(
                      children: [
                        const FlameLogo(size: 54),
                        const SizedBox(height: 14),
                        Text('No skills yet',
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          'Plug in an MCP server and the dragon gains\n'
                          'its tools — repos, issues, builds, docs.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .copyWith(height: 1.5),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: DragonColors.ember,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _addServerSheet(context),
                          icon: const Icon(Icons.extension_rounded),
                          label: const Text('Add GitHub or Cloudflare'),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  for (final s in mcp.servers)
                    _ServerCard(cfg: s),
                  const SizedBox(height: 12),
                  Text(
                    'Tools appear as mcp_<server>_<tool> and are offered to '
                    'the model automatically on every turn.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .copyWith(fontSize: 11.5),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _addServerSheet(BuildContext context) async {
    final preset = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PresetSheet(),
    );
    if (preset == null || !context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ServerForm(preset: preset),
    );
  }
}

// ------------------------------------------------------------------

class _ServerCard extends StatefulWidget {
  final McpServerCfg cfg;
  const _ServerCard({required this.cfg});

  @override
  State<_ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends State<_ServerCard> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final mcp = state.mcp;
    final cfg = widget.cfg;
    final tools = mcp.toolsOf(cfg.id);
    final error = mcp.errors[cfg.id];
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: dark ? DragonColors.card : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => open = !open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.extension_rounded,
                        size: 19,
                        color: cfg.enabled ? DragonColors.gold : DragonColors.textDim),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cfg.name,
                              style: const TextStyle(
                                  fontSize: 14.5, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            cfg.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5,
                                fontFamily: 'monospace',
                                color: DragonColors.textDim),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Switch(
                          value: cfg.enabled,
                          onChanged: (v) {
                            mcp.setEnabled(cfg, v);
                            state.saveMcpServers();
                            if (v) {
                              () async {
                                try {
                                  await mcp.refreshServer(cfg);
                                } catch (_) {}
                              }();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (error != null)
                      Expanded(
                        child: Text(
                          error,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5, color: DragonColors.emberDeep),
                        ),
                      )
                    else
                      Expanded(
                        child: Text(
                          '${tools.length} tools',
                          style: TextStyle(
                              fontSize: 12, color: DragonColors.textDim),
                        ),
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Reconnect',
                      onPressed: () async {
                        try {
                          await mcp.refreshServer(cfg);
                        } catch (_) {}
                      },
                      icon: const Icon(Icons.refresh_rounded,
                          size: 19, color: DragonColors.textDim),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Remove',
                      onPressed: () {
                        mcp.remove(cfg.id);
                        state.saveMcpServers();
                      },
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 19, color: DragonColors.textDim),
                    ),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 19, color: DragonColors.textDim),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 200),
                  crossFadeState:
                      open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: tools.isEmpty
                        ? Text(
                            'no tools loaded — reconnect once the server is reachable',
                            style: TextStyle(
                                fontSize: 12, color: DragonColors.textDim),
                          )
                        : Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              for (final t in tools)
                                Tooltip(
                                  message: t.description,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: DragonColors.ember
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: DragonColors.ember
                                              .withValues(alpha: 0.18)),
                                    ),
                                    child: Text(
                                      t.name,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ),
                                ),
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

// ------------------------------------------------------------------

class _PresetSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
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
            Text('Add a skill source',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 14),
            for (final p in mcpPresets)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: DragonColors.ember.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    p['name']!.substring(0, 1),
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: DragonColors.ember),
                  ),
                ),
                title: Text(p['name']!,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(p['hint']!,
                    style: TextStyle(fontSize: 11.5, color: DragonColors.textDim)),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: DragonColors.textDim),
                onTap: () => Navigator.pop(context, p),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------

class _ServerForm extends StatefulWidget {
  final Map<String, String> preset;
  const _ServerForm({required this.preset});

  @override
  State<_ServerForm> createState() => _ServerFormState();
}

class _ServerFormState extends State<_ServerForm> {
  late final _name = TextEditingController(text: widget.preset['name'] ?? '');
  late final _url = TextEditingController(text: widget.preset['url'] ?? '');
  final _token = TextEditingController();
  var _showToken = false;
  var _saving = false;

  bool get _valid =>
      _name.text.trim().isNotEmpty && _url.text.trim().startsWith('http');

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final cfg = state.mcp.add(McpServerCfg(
      id: const Uuid().v4().replaceAll('-', '').substring(0, 10),
      name: _name.text.trim(),
      url: _url.text.trim(),
      token: _token.text.trim(),
    ));
    await state.saveMcpServers();
    String? error;
    try {
      await state.mcp.refreshServer(cfg);
    } on McpException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'connection failed';
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(error == null
            ? '${cfg.name} connected · ${state.mcp.toolsOf(cfg.id).length} tools'
            : 'Saved, but: $error'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
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
              Text('Connect ${widget.preset['name']}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'MCP endpoint',
                  hintText: 'https://…/mcp',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _token,
                obscureText: !_showToken,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Bearer token (optional)',
                  suffixIcon: IconButton(
                    icon: Icon(
                        _showToken
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 20,
                        color: DragonColors.textDim),
                    onPressed: () => setState(() => _showToken = !_showToken),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: DragonColors.ember,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _valid && !_saving ? _save : null,
                  icon: _saving
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: Colors.white))
                      : const Icon(Icons.bolt_rounded),
                  label: const Text('Connect & load tools'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
