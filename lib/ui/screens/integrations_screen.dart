import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../state/app_state.dart';

/// Direct account connections — GitHub and Cloudflare, full access via PAT.
class IntegrationsScreen extends StatefulWidget {
  const IntegrationsScreen({super.key});

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen> {
  late final _gh = TextEditingController();
  late final _cf = TextEditingController();
  var _showGh = false;
  var _showCf = false;
  var _testingGh = false;
  var _testingCf = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _gh.text = state.github.token;
    _cf.text = state.cloudflare.token;
  }

  @override
  void dispose() {
    _gh.dispose();
    _cf.dispose();
    super.dispose();
  }

  Future<void> _saveGh() async {
    final state = context.read<AppState>();
    state.github.token = _gh.text.trim();
    await state.saveTokens();
    setState(() => _testingGh = true);
    String msg;
    try {
      final r = await state.github.handleTool('gh_list_repos', {});
      msg = 'Connected · ${r.contains('"repos"') ? "repos loaded" : "ok"}';
    } catch (e) {
      msg = 'Saved, but test failed: $e';
    }
    if (!mounted) return;
    setState(() => _testingGh = false);
    _toast(msg);
  }

  Future<void> _saveCf() async {
    final state = context.read<AppState>();
    state.cloudflare.token = _cf.text.trim();
    await state.saveTokens();
    setState(() => _testingCf = true);
    String msg;
    try {
      await state.cloudflare.handleTool('cf_accounts', {});
      msg = 'Connected · account found';
    } catch (e) {
      msg = 'Saved, but test failed: $e';
    }
    if (!mounted) return;
    setState(() => _testingCf = false);
    _toast(msg);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Connect accounts')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
        children: [
          _IntegrationCard(
            dark: dark,
            icon: Icons.code_rounded,
            name: 'GitHub',
            connected: state.github.connected,
            description:
                'Full repo access with a personal access token — create repos, '
                'push code, open issues & PRs, dispatch Actions builds.',
            controller: _gh,
            obscure: !_showGh,
            onToggleVisibility: () => setState(() => _showGh = !_showGh),
            testing: _testingGh,
            onSave: _saveGh,
            scopes: 'Scopes: repo · workflow',
          ),
          const SizedBox(height: 14),
          _IntegrationCard(
            dark: dark,
            icon: Icons.cloud_rounded,
            name: 'Cloudflare',
            connected: state.cloudflare.connected,
            description:
                'Manage KV namespaces, D1 databases and deploy Workers with an '
                'API token. The dragon can build and ship backends for you.',
            controller: _cf,
            obscure: !_showCf,
            onToggleVisibility: () => setState(() => _showCf = !_showCf),
            testing: _testingCf,
            onSave: _saveCf,
            scopes: 'Permissions: Workers Scripts · D1 · Workers KV Storage — Edit',
          ),
          const SizedBox(height: 18),
          Text(
            'Tokens are stored only on this device and sent directly to the '
            'provider. The agent can only reach the accounts these tokens '
            'grant — revoke them any time on the provider side.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall!
                .copyWith(fontSize: 11.5, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _IntegrationCard extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String name;
  final bool connected;
  final String description;
  final String scopes;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggleVisibility;
  final bool testing;
  final VoidCallback onSave;

  const _IntegrationCard({
    required this.dark,
    required this.icon,
    required this.name,
    required this.connected,
    required this.description,
    required this.controller,
    required this.obscure,
    required this.onToggleVisibility,
    required this.testing,
    required this.onSave,
    required this.scopes,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dark ? DragonColors.card : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: DragonColors.emberGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 19, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w800)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: connected
                        ? DragonColors.success.withValues(alpha: 0.12)
                        : DragonColors.textDim.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    connected ? 'connected' : 'not connected',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: connected ? DragonColors.success : DragonColors.textDim,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(description,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.55,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55))),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              obscureText: obscure,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'API token',
                suffixIcon: IconButton(
                  icon: Icon(
                      obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20,
                      color: DragonColors.textDim),
                  onPressed: onToggleVisibility,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(scopes,
                style: TextStyle(
                    fontSize: 11, color: DragonColors.textDim)),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: DragonColors.ember,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: testing ? null : onSave,
                icon: testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: Colors.white))
                    : const Icon(Icons.bolt_rounded),
                label: const Text('Save & test connection'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
