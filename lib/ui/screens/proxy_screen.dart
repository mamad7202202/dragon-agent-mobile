import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../services/proxy_service.dart';
import '../../state/app_state.dart';

/// Proxy configuration — route AI and/or integration traffic through a
/// user-supplied intermediary server (HTTP/HTTPS, optional auth).
class ProxyScreen extends StatefulWidget {
  const ProxyScreen({super.key});

  @override
  State<ProxyScreen> createState() => _ProxyScreenState();
}

class _ProxyScreenState extends State<ProxyScreen> {
  late ProxyConfig _cfg;
  late final _server = TextEditingController();
  var _testing = false;
  String? _testResult; // null = untested · '' = ok · text = error
  var _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _cfg = ProxyConfig.fromJson(context.read<AppState>().proxy.toJson());
    _server.text = _cfg.server;
  }

  @override
  void dispose() {
    _server.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _cfg.server = _server.text.trim();
    await context.read<AppState>().saveProxy(_cfg);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Proxy settings saved')));
    Navigator.pop(context);
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final err = await ProxyHttp.test(
      ProxyConfig.fromJson(_cfg.toJson())..server = _server.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = err ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final providerNames = state.providers.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Proxy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
        children: [
          Text(
            'Send requests through your own intermediary server — useful for '
            'censorship circumvention, corporate networks or auditing.',
            style: Theme.of(context)
                .textTheme
                .bodySmall!
                .copyWith(fontSize: 12.5, height: 1.55),
          ),
          const SizedBox(height: 14),

          // ---- master switch ----
          _Card(
            dark: dark,
            child: Row(
              children: [
                Icon(Icons.vpn_lock_rounded,
                    color: _cfg.enabled ? DragonColors.gold : DragonColors.textDim),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Use proxy',
                          style: TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w600)),
                      Text(
                        _cfg.enabled ? 'On' : 'Off — direct connections',
                        style: TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _cfg.enabled,
                  onChanged: (v) => setState(() => _cfg.enabled = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ---- server ----
          _Card(
            dark: dark,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _server,
                  autocorrect: false,
                  enabled: true,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Server',
                    hintText: 'proxy.example.com:8080',
                    helperText:
                        'host[:port] or http(s)://user:pass@host:port',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _test,
                  icon: _testing
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.network_check_rounded, size: 18),
                  label: const Text('Test connection'),
                ),
              ),
              if (_testResult != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _testResult!.isEmpty ? 'Reachable ✓' : _testResult!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _testResult!.isEmpty
                          ? DragonColors.success
                          : DragonColors.emberDeep,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // ---- scopes ----
          _SectionHeader('What goes through the proxy'),
          _SwitchTile(
            dark: dark,
            icon: Icons.auto_awesome_rounded,
            title: 'AI providers',
            subtitle: 'Chat & completion requests to the model provider',
            value: _cfg.ai,
            onChanged: (v) => setState(() => _cfg.ai = v),
          ),
          if (_cfg.ai && providerNames.isNotEmpty) ...[
            const SizedBox(height: 8),
            _Card(
              dark: dark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.alt_route_rounded,
                          size: 19, color: DragonColors.gold),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _cfg.aiProvider.isEmpty
                              ? 'All providers go through the proxy'
                              : 'Only “${_cfg.aiProvider}” goes through the proxy',
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pick one provider to proxy, or leave on “all”.',
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All providers'),
                        selected: _cfg.aiProvider.isEmpty,
                        onSelected: (_) =>
                            setState(() => _cfg.aiProvider = ''),
                        selectedColor: DragonColors.ember,
                        backgroundColor: dark ? DragonColors.card : Colors.white,
                        side: BorderSide(color: DragonColors.stroke),
                        showCheckmark: false,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _cfg.aiProvider.isEmpty ? Colors.white : null,
                        ),
                      ),
                      for (final name in providerNames)
                        ChoiceChip(
                          label: Text(name),
                          selected: _cfg.aiProvider == name,
                          onSelected: (_) =>
                              setState(() => _cfg.aiProvider = name),
                          selectedColor: DragonColors.ember,
                          backgroundColor:
                              dark ? DragonColors.card : Colors.white,
                          side: BorderSide(color: DragonColors.stroke),
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _cfg.aiProvider == name ? Colors.white : null,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          _SwitchTile(
            dark: dark,
            icon: Icons.handyman_rounded,
            title: 'Integrations & tools',
            subtitle:
                'GitHub · Cloudflare · skills library · update downloads',
            value: _cfg.integrations,
            onChanged: (v) => setState(() => _cfg.integrations = v),
          ),
          const SizedBox(height: 16),

          // ---- advanced (auth) ----
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
              icon: AnimatedRotation(
                turns: _showAdvanced ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              ),
              label: const Text('Authentication'),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _showAdvanced
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _Card(
                dark: dark,
                child: Text(
                  'Include user & password in the server field:\n'
                  'http://username:password@proxy.example.com:8080\n\n'
                  'SOCKS proxies are not supported — use an HTTP/HTTPS '
                  'proxy (most tools expose one).',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: DragonColors.textDim,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
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
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save proxy settings',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- widgets

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8, top: 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final bool dark;
  final Widget child;
  const _Card({required this.dark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dark ? DragonColors.card : Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.dark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dark ? DragonColors.card : Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon,
                  color: value ? DragonColors.gold : DragonColors.textDim),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}
