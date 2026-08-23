import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/memory.dart';
import '../widgets/flame_logo.dart';

/// Memory manager — semantic facts + procedural MEMORY.md.
class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 2, vsync: this, initialIndex: _initialTab)
        ..addListener(() {
          if (mounted) setState(() {});
        });
  final _search = TextEditingController();

  static const _initialTab = 0;

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final facts = state.memory.all;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memories'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: DragonColors.ember,
          labelColor: Theme.of(context).colorScheme.onSurface,
          unselectedLabelColor: DragonColors.textDim,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Facts', icon: Icon(Icons.auto_awesome_rounded, size: 17)),
            Tab(text: 'Rules · MEMORY.md', icon: Icon(Icons.rule_rounded, size: 17)),
          ],
        ),
      ),
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton.extended(
              heroTag: 'add-fact',
              onPressed: () => _addFactDialog(context),
              backgroundColor: DragonColors.ember,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Remember something'),
            )
          : null,
      body: TabBarView(
        controller: _tabs,
        children: [
          // ---------------- facts ----------------
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
                child: facts.isEmpty
                    ? _EmptyMemories()
                    : Builder(builder: (context) {
                        final q = _search.text.toLowerCase().trim();
                        final filtered = q.isEmpty
                            ? facts
                            : facts.where((f) =>
                                f.content.toLowerCase().contains(q)).toList();
                        if (filtered.isEmpty) {
                          return Center(
                            child: Text('Nothing matches “${_search.text}”',
                                style: Theme.of(context).textTheme.bodySmall),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => _FactCard(fact: filtered[i]),
                        );
                      }),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: const Text('Pin a fact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                autofocus: true,
                minLines: 1,
                maxLines: 3,
                decoration:
                    const InputDecoration(hintText: 'e.g. I prefer dark mode everywhere'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('Importance',
                      style: Theme.of(context).textTheme.bodySmall),
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
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty && mounted) {
      context.read<AppState>().memory.add(ctrl.text.trim(), importance: importance);
      // persist through a dummy recall to trigger save — cleaner: call saveFacts via state
      // ignore: invalid_use_of_protected_member
      await context.read<AppState>().memory.saveFacts();
      if (mounted) setState(() {});
    }
  }
}

// ------------------------------------------------------------------

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
        onLongPress: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Forget this fact?'),
              content: Text(fact.content),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Keep')),
                FilledButton(
                  onPressed: () {
                    context.read<AppState>().memory.remove(fact.id);
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(backgroundColor: DragonColors.emberDeep),
                  child: const Text('Forget'),
                ),
              ],
            ),
          );
        },
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
                    Text(fact.content, style: const TextStyle(fontSize: 14, height: 1.45)),
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
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FlameLogo(size: 54),
          const SizedBox(height: 14),
          Text('No facts yet', style: Theme.of(context).textTheme.titleMedium),
          Text('Tell Dragon things worth remembering,\nor tap “Remember something”.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(height: 1.5)),
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

  Future<void> _load() async {
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
                  style: TextStyle(fontSize: 13.5, height: 1.55, fontFamily: 'monospace'),
                  onChanged: (_) => setState(() => _dirty = true),
                  decoration: InputDecoration(
                    hintText: '# Rules\n\n- Always answer in Persian\n- My timezone is +3:30',
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
