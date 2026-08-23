import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../state/app_state.dart';
import '../widgets/flame_logo.dart';
import 'memories_screen.dart';
import 'sessions_screen.dart';
import 'setup_wizard.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
        children: [
          // ---------------- provider ----------------
          _SectionHeader('Model provider'),
          _CardTile(
            leading: const Icon(Icons.cloud_rounded, color: DragonColors.gold),
            title: state.configured ? state.activeProvider : 'not configured',
            subtitle:
                '${state.activeModel} · ${state.providers.length} provider(s)',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SetupWizard(editMode: true))),
          ),
          const SizedBox(height: 8),

          _SectionHeader('Generation'),
          _CardTile(
            padding: EdgeInsets.zero,
            title: 'Temperature',
            subtitle: 'Creativity · ${s.temperature.toStringAsFixed(1)}',
            content: Slider(
              value: s.temperature,
              min: 0,
              max: 1,
              divisions: 10,
              label: s.temperature.toStringAsFixed(1),
              onChanged: (v) => context
                  .read<AppState>()
                  .updateSettings(s..temperature = v),
            ),
          ),
          const SizedBox(height: 8),
          _CardTile(
            padding: EdgeInsets.zero,
            title: 'Max tokens',
            subtitle: 'Response length cap · ${s.maxTokens}',
            content: Slider(
              value: s.maxTokens.toDouble(),
              min: 512,
              max: 8192,
              divisions: 15,
              label: '${s.maxTokens}',
              onChanged: (v) =>
                  context.read<AppState>().updateSettings(s..maxTokens = v.round()),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            tileColor: Theme.of(context).brightness == Brightness.dark
                ? DragonColors.card
                : Colors.white,
            title: const Text('Hybrid memory', style: TextStyle(fontSize: 14.5)),
            subtitle: Text('Inject facts & rules into every prompt',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall!
                    .copyWith(fontSize: 12)),
            activeColor: DragonColors.ember,
            value: s.memoryEnabled,
            onChanged: (v) =>
                context.read<AppState>().updateSettings(s..memoryEnabled = v),
          ),
          const SizedBox(height: 8),
          _CardTile(
            padding: EdgeInsets.zero,
            title: 'Compaction threshold',
            subtitle:
                'Fold older turns into a summary after ${s.compactionAfter} messages',
            content: Slider(
              value: s.compactionAfter.toDouble(),
              min: 12,
              max: 80,
              divisions: 17,
              label: '${s.compactionAfter}',
              onChanged: (v) => context
                  .read<AppState>()
                  .updateSettings(s..compactionAfter = v.round()),
            ),
          ),
          const SizedBox(height: 16),

          _SectionHeader('Memory'),
          _CardTile(
            leading: Icon(Icons.auto_awesome_rounded, color: DragonColors.gold),
            title: 'Facts & rules',
            subtitle: '${state.memory.all.length} facts saved on this device',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MemoriesScreen())),
          ),
          const SizedBox(height: 8),
          _CardTile(
            leading: Icon(Icons.forum_outlined, color: DragonColors.gold),
            title: 'Sessions',
            subtitle: '${state.sessions.metas.length} resumable transcripts',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SessionsScreen())),
          ),
          const SizedBox(height: 16),

          _SectionHeader('About'),
          _CardTile(
            leading: const FlameLogo(size: 30),
            title: 'Dragon Agent Mobile',
            subtitle:
                'v1.0.0 · open-source · MIT\nCompanion to the desktop dragon-agent',
            isLast: true,
            onTap: () => launchUrl(
                Uri.parse('https://github.com/mamad7202202/dragon-agent'),
                mode: LaunchMode.externalApplication),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: DragonColors.emberDeep),
              onPressed: () => _confirmReset(context),
              icon: const Icon(Icons.dangerous_outlined, size: 18),
              label: const Text('Reset app — wipe keys, memories & sessions'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset everything?'),
        content: const Text(
            'This deletes API keys, all facts, MEMORY.md and every session '
            'transcript stored on this device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DragonColors.emberDeep),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<AppState>().resetEverything();
    }
  }
}

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
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget? content;
  final EdgeInsets padding;
  final bool isLast;

  const _CardTile({
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.content,
    this.padding = const EdgeInsets.all(14),
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).brightness == Brightness.dark
          ? DragonColors.card
          : Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding.copyWith(left: 18, right: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 13)],
                  Expanded(
                    child: Text(title,
                        style:
                            const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                  ),
                  if (trailing != null)
                    IconTheme.merge(
                      data: IconThemeData(color: DragonColors.textDim, size: 22),
                      child: trailing!,
                    ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
              if (content != null) content!,
              if (isLast) const SizedBox(height: 2),
            ],
          ),
        ),
      ),
    );
  }
}
