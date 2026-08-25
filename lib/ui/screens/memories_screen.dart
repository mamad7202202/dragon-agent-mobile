import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/graph_memory.dart';
import '../../data/memory.dart';
import '../../state/app_state.dart';
import '../widgets/dragon_mark.dart';

/// Memory manager — adapts to the active engine:
/// Hybrid → semantic facts · Outline → sections & bullets.
class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 2, vsync: this, initialIndex: 0)
        ..addListener(() {
          if (mounted) setState(() {});
        });
  final _search = TextEditingController();

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isOutline = state.settings.mode == MemoryMode.outline;

    return Scaffold(
      appBar: AppBar(
        title: Text(isOutline ? 'Memory outline' : 'Memories'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: DragonColors.ember,
          labelColor: Theme.of(context).colorScheme.onSurface,
          unselectedLabelColor: DragonColors.textDim,
          dividerColor: Colors.transparent,
          tabs: [
            Tab(
                text: isOutline ? 'Outline' : 'Facts',
                icon: Icon(
                    isOutline
                        ? Icons.account_tree_rounded
                        : Icons.auto_awesome_rounded,
                    size: 17)),
            const Tab(
                text: 'Rules · MEMORY.md',
                icon: Icon(Icons.rule_rounded, size: 17)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-memory',
        onPressed: () => isOutline ? _addBulletsDialog(context) : _addFactDialog(context),
        backgroundColor: DragonColors.ember,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(isOutline ? 'Add bullets' : 'Remember something'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ---------------- facts / outline ----------------
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search memories…',
                    prefixIcon:
                        Icon(Icons.search_rounded, color: DragonColors.textDim),
                  ),
                ),
              ),
              Expanded(
                child: isOutline
                    ? _OutlineList(search: _search.text)
                    : _FactsList(search: _search.text),
              ),
            ],
          ),
          // ---------------- memory.md ----------------
          const _MemoryMdEditor(),
        ],
      ),
    );
  }

  Future<void> _addFactDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    double importance = 0.5;
    final ok = await _formDialog(
      title: 'Pin a fact',
      hint: 'e.g. I prefer dark mode everywhere',
      ctrl: ctrl,
      extra: StatefulBuilder(
        builder: (context, setD) => Row(
          children: [
            Text('Importance', style: Theme.of(context).textTheme.bodySmall),
            Expanded(
              child: Slider(
                value: importance,
                divisions: 10,
                label: importance.toStringAsFixed(1),
                onChanged: (v) => setD(() => importance = v),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty && mounted) {
      context
          .read<AppState>()
          .memory
          .add(ctrl.text.trim(), importance: importance);
      await context.read<AppState>().memory.saveFacts();
      if (mounted) setState(() {});
    }
  }

  Future<void> _addBulletsDialog(BuildContext context) async {
    final sectionCtrl = TextEditingController(text: 'facts');
    final bulletsCtrl = TextEditingController();
    final ok = await _formDialog(
      title: 'Add to outline',
      hint: 'one bullet per line, self-contained',
      ctrl: bulletsCtrl,
      maxLines: 5,
      extra: TextField(
        controller: sectionCtrl,
        decoration: const InputDecoration(
          labelText: 'Section',
          hintText: 'profile · preferences · projects · people · goals · facts',
        ),
      ),
    );
    if (ok == true && bulletsCtrl.text.trim().isNotEmpty && mounted) {
      final bullets = bulletsCtrl.text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      context.read<AppState>().graph.write(sectionCtrl.text, bullets);
      await context.read<AppState>().graph.save();
      if (mounted) setState(() {});
    }
  }

  Future<bool?> _formDialog({
    required String title,
    required String hint,
    required TextEditingController ctrl,
    Widget? extra,
    int maxLines = 3,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 1,
              maxLines: maxLines,
              decoration: InputDecoration(hintText: hint),
            ),
            const SizedBox(height: 14),
            extra ?? const SizedBox.shrink(),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: DragonColors.ember),
              child: const Text('Save')),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------
// hybrid facts list
// ------------------------------------------------------------------

class _FactsList extends StatelessWidget {
  final String search;
  const _FactsList({required this.search});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final facts = state.memory.all;
    if (facts.isEmpty) {
      return const _EmptyMemories();
    }
    final q = search.toLowerCase().trim();
    final filtered = q.isEmpty
        ? facts
        : facts.where((f) => f.content.toLowerCase().contains(q)).toList();
    if (filtered.isEmpty) {
      return Center(
        child: Text('Nothing matches “$search”',
            style: Theme.of(context).textTheme.bodySmall),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _FactCard(fact: filtered[i]),
    );
  }
}

class _FactCard extends StatelessWidget {
  final Fact fact;
  const _FactCard({required this.fact});

  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().difference(fact.createdAt);
    final ageText = age.inDays > 0 ? '${age.inDays}d' : '${age.inHours}h';
    return Material(
      color: Theme.of(context).brightness == Brightness.dark
          ? DragonColors.card
          : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onLongPress: () => _confirmForget(context, fact.id, fact.content),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    DragonColors.gold.withValues(alpha: 0.25),
                    DragonColors.ember.withValues(alpha: 0.15),
                  ]),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  fact.id.substring(0, 2),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: DragonColors.gold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fact.content,
                        style:
                            const TextStyle(fontSize: 14, height: 1.45)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _MiniBadge('$ageText old'),
                        const SizedBox(width: 6),
                        _ImportanceBar(value: fact.importance),
                        const Spacer(),
                        Text('#${fact.id}',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                                color: DragonColors.textDim)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _confirmForget(BuildContext context, String id, String preview,
    {bool isSection = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(isSection ? 'Clear section?' : 'Forget this?'),
      content: Text(preview),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style:
              FilledButton.styleFrom(backgroundColor: DragonColors.emberDeep),
          child: const Text('Forget'),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    final state = context.read<AppState>();
    if (isSection) {
      state.graph.remove(section: id);
      await state.graph.save();
    } else {
      state.memory.remove(id);
      await state.memory.saveFacts();
    }
  }
}

// ------------------------------------------------------------------
// outline (graph) list
// ------------------------------------------------------------------

class _OutlineList extends StatelessWidget {
  final String search;
  const _OutlineList({required this.search});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final graph = state.graph;
    if (graph.entryCount == 0) {
      return const _EmptyOutline();
    }
    final q = search.toLowerCase().trim();

    final sections = graph.sections.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => MapEntry(e.key, e.value))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        for (final entry in sections)
          if (q.isEmpty ||
              entry.key.contains(q) ||
              entry.value.any((e) => e.text.toLowerCase().contains(q)))
            _OutlineSection(
              name: entry.key,
              entries: entry.value
                  .where((e) =>
                      q.isEmpty || e.text.toLowerCase().contains(q))
                  .toList(),
            ),
      ],
    );
  }
}

class _OutlineSection extends StatelessWidget {
  final String name;
  final List<GraphEntry> entries;
  const _OutlineSection({required this.name, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: DragonColors.emberGradient,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${entries.length}',
                  style: TextStyle(
                      fontSize: 11, color: DragonColors.textDim)),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.delete_sweep_outlined,
                    size: 18, color: DragonColors.textDim),
                onPressed: () => _confirmForget(
                    context, name, 'Entire “$name” section',
                    isSection: true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? DragonColors.card
                          : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onLongPress: () =>
                        _confirmForget(context, e.id, e.text),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 30,
                            decoration: BoxDecoration(
                              gradient: DragonColors.emberGradient,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Text(e.text,
                                style: const TextStyle(
                                    fontSize: 13.5, height: 1.4)),
                          ),
                          const SizedBox(width: 8),
                          Text('#${e.id}',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  color: DragonColors.textDim)),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _EmptyOutline extends StatelessWidget {
  const _EmptyOutline();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DragonAscii(fontSize: 5.6),
          const SizedBox(height: 14),
          Text('The outline is empty',
              style: Theme.of(context).textTheme.titleMedium),
          Text(
            'Dragon fills sections automatically as it learns —\nor add bullets yourself.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall!
                .copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------

class _MiniBadge extends StatelessWidget {
  final String text;
  const _MiniBadge(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: DragonColors.stroke,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10.5, color: DragonColors.textDim),
      ),
    );
  }
}

class _ImportanceBar extends StatelessWidget {
  final double value;
  const _ImportanceBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 5; i++)
          Container(
            width: 9,
            height: 4,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: i < (value * 5).round()
                  ? DragonColors.ember
                  : DragonColors.stroke,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}

class _EmptyMemories extends StatelessWidget {
  const _EmptyMemories();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DragonAscii(fontSize: 5.6),
          const SizedBox(height: 14),
          Text('No facts yet', style: Theme.of(context).textTheme.titleMedium),
          Text(
              'Tell Dragon things worth remembering,\nor tap “Remember something”.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall!
                  .copyWith(height: 1.5)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------

class _MemoryMdEditor extends StatefulWidget {
  const _MemoryMdEditor();

  @override
  State<_MemoryMdEditor> createState() => _MemoryMdEditorState();
}

class _MemoryMdEditorState extends State<_MemoryMdEditor> {
  late final TextEditingController _ctrl;
  var _dirty = false;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _load();
  }

  void _load() {
    final state = context.read<AppState>();
    _ctrl.text = state.memory.procedural;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Standing instructions, always loaded into every prompt.',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(
                      fontSize: 13.5, height: 1.55, fontFamily: 'monospace'),
                  onChanged: (_) => setState(() => _dirty = true),
                  decoration: const InputDecoration(
                    hintText:
                        '# Rules\n\n- Always answer in Persian\n- My timezone is +3:30',
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 20,
          bottom: 24,
          child: AnimatedScale(
            scale: _dirty ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: FloatingActionButton.extended(
              heroTag: 'save-md',
              onPressed: _dirty ? _save : null,
              backgroundColor: DragonColors.ember,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save rules'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    await state.memory.saveProcedural(_ctrl.text);
    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('MEMORY.md saved')));
  }
}
