import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/llm.dart' show ThinkingLevel, ThinkingLevelX;
import '../../services/update_service.dart' show UpdatePhase;
import '../../state/app_state.dart';
import '../widgets/flame_logo.dart';
import '../widgets/update_banner.dart';
import 'integrations_screen.dart';
import 'memories_screen.dart';
import 'sessions_screen.dart';
import 'setup_wizard.dart';
import 'skills_library_screen.dart';

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
          _CardTile(
            leading:
                const Icon(Icons.extension_rounded, color: DragonColors.gold),
            title: 'Skills',
            subtitle:
                '${state.skills.all.length} installed · find SKILL.md files on GitHub',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SkillsLibraryScreen())),
          ),
          const SizedBox(height: 8),
          _CardTile(
            leading: const Icon(Icons.link_rounded, color: DragonColors.gold),
            title: 'Connect accounts',
            subtitle:
                'GitHub · Cloudflare — full access for the agent to build & ship',
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const IntegrationsScreen())),
          ),
          const SizedBox(height: 16),

          // ---------------- appearance ----------------
          _SectionHeader('Appearance'),
          _SegmentCard(
            title: 'Theme',
            segments: const ['System', 'Light', 'Dark'],
            selectedIndex: s.themeMode,
            onChanged: (i) =>
                context.read<AppState>().updateSettings(s..themeMode = i),
          ),
          const SizedBox(height: 16),

          // ---------------- intelligence ----------------
          _SectionHeader('Intelligence'),
          _SegmentCard(
            title: 'Deep thinking',
            subtitle:
                'Higher = smarter & slower · uses reasoning tokens on capable models',
            segments: ThinkingLevel.values.map((t) => t.label).toList(),
            selectedIndex: s.thinking,
            onChanged: (i) =>
                context.read<AppState>().updateSettings(s..thinking = i),
          ),
          const SizedBox(height: 8),
          _CardTile(
            leading: Icon(Icons.travel_explore_rounded,
                color: state.cfg?.supportsWebSearch ?? false
                    ? DragonColors.gold
                    : DragonColors.textDim),
            title: 'Web search',
            subtitle: (state.cfg?.supportsWebSearch ?? false)
                ? 'Ground answers with live web results (OpenRouter · Anthropic)'
                : 'Not supported by this provider — switch to OpenRouter or Anthropic',
            trailing: Switch(
              value: s.webSearch && (state.cfg?.supportsWebSearch ?? false),
              onChanged: (state.cfg?.supportsWebSearch ?? false)
                  ? (v) => context
                      .read<AppState>()
                      .updateSettings(s..webSearch = v)
                  : null,
            ),
            onTap: (state.cfg?.supportsWebSearch ?? false)
                ? () => context
                    .read<AppState>()
                    .updateSettings(s..webSearch = !s.webSearch)
                : null,
          ),
          const SizedBox(height: 8),
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
              onChanged: (v) =>
                  context.read<AppState>().updateSettings(s..temperature = v),
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

          // ---------------- memory ----------------
          _SectionHeader('Memory'),
          _SegmentCard(
            title: 'Memory engine',
            subtitle: s.memoryMode == 0
                ? 'Hybrid — scored facts + rules + sessions (classic Dragon)'
                : 'Outline — sections & bullets, ultra token-efficient recall',
            segments: const ['Hybrid', 'Outline'],
            selectedIndex: s.memoryMode,
            onChanged: (i) =>
                context.read<AppState>().updateSettings(s..memoryMode = i),
          ),
          const SizedBox(height: 8),
          _CardTile(
            leading: Icon(Icons.psychology_alt_rounded,
                color: s.memoryEnabled ? DragonColors.gold : DragonColors.textDim),
            title: 'Memory active',
            subtitle: 'Inject memory into every prompt',
            trailing: Switch(
              value: s.memoryEnabled,
              onChanged: (v) =>
                  context.read<AppState>().updateSettings(s..memoryEnabled = v),
            ),
            onTap: () => context
                .read<AppState>()
                .updateSettings(s..memoryEnabled = !s.memoryEnabled),
          ),
          const SizedBox(height: 8),
          _CardTile(
            leading: Icon(Icons.auto_awesome_rounded, color: DragonColors.gold),
            title: 'Facts, rules & outline',
            subtitle: state.settings.mode == MemoryMode.outline
                ? '${state.graph.entryCount} bullets in ${state.graph.sectionCount} sections'
                : '${state.memory.all.length} facts saved on this device',
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

          // ---------------- updates ----------------
          _SectionHeader('Updates'),
          _CardTile(
            leading: const Icon(Icons.system_update_alt_rounded,
                color: DragonColors.gold),
            title: 'Check for updates',
            subtitle: state.lastUpdateNotice ??
                'Current version ${state.appVersion} · auto-checked on connect',
            trailing: state.updatePhase == UpdatePhase.checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: DragonColors.ember))
                : const Icon(Icons.chevron_right_rounded),
            onTap: state.updatePhase == UpdatePhase.checking
                ? null
                : () async {
                    await context.read<AppState>().checkForUpdates(manual: true);
                    if (!context.mounted) return;
                    final st = context.read<AppState>();
                    if (st.pendingUpdate != null) {
                      showUpdateSheet(context);
                    } else {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                            content: Text(st.lastUpdateNotice ??
                                'You are on the latest version.')));
                    }
                  },
          ),
          const SizedBox(height: 16),

          // ---------------- about ----------------
          _SectionHeader('About'),
          _CardTile(
            leading: const FlameLogo(size: 30),
            title: 'Dragon Agent Mobile',
            subtitle:
                'v${state.appVersion} · open-source · MIT\nCompanion to the desktop dragon-agent',
            isLast: true,
            onTap: () => launchUrl(
                Uri.parse('https://mamad7202202.github.io/dragon-agent-mobile/'),
                mode: LaunchMode.externalApplication),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              style:
                  TextButton.styleFrom(foregroundColor: DragonColors.emberDeep),
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
            'This deletes API keys, all facts, the memory outline, MEMORY.md '
            'and every session transcript stored on this device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: DragonColors.emberDeep),
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

// ------------------------------------------------------------------

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

/// Segmented selector inside a card (theme, thinking, memory engine…).
class _SegmentCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentCard({
    required this.title,
    this.subtitle,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? DragonColors.card : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: segments
                    .map((s) => ButtonSegment(value: segments.indexOf(s), label: Text(s)))
                    .toList(),
                selected: {selectedIndex},
                onSelectionChanged: (set) => onChanged(set.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  )),
                  backgroundColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected)
                          ? DragonColors.ember
                          : Colors.transparent),
                  foregroundColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected)
                          ? Colors.white
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6)),
                  side: WidgetStatePropertyAll(BorderSide(
                      color: dark
                          ? DragonColors.stroke
                          : const Color(0x14000000))),
                  shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ),
          ],
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? DragonColors.card : Colors.white,
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
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w600)),
                  ),
                  if (trailing != null)
                    IconTheme.merge(
                      data:
                          IconThemeData(color: DragonColors.textDim, size: 22),
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
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
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
