import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../services/skills.dart';
import '../../state/app_state.dart';

/// SKILL.md library — search trusted GitHub sources, import, manage.
class SkillsLibraryScreen extends StatefulWidget {
  const SkillsLibraryScreen({super.key});

  @override
  State<SkillsLibraryScreen> createState() => _SkillsLibraryScreenState();
}

class _SkillsLibraryScreenState extends State<SkillsLibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 2, vsync: this)..addListener(() {
        if (mounted) setState(() {});
      });
  final _search = TextEditingController();
  var _searching = false;
  List<SkillHit> _hits = [];
  String? _searchError;
  final Set<String> _importing = {};

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final state = context.read<AppState>();
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final hits = await state.skills.search(_search.text);
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = 'Search failed — GitHub may be rate-limiting. Try again.';
        _searching = false;
      });
    }
  }

  Future<void> _import(SkillHit hit) async {
    final state = context.read<AppState>();
    setState(() => _importing.add(hit.path));
    try {
      final skill = await state.skills.import(hit);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
            content: Text('Imported "${skill.name}" — type / in chat to use it')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      if (mounted) setState(() => _importing.remove(hit.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skills'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: DragonColors.ember,
          labelColor: Theme.of(context).colorScheme.onSurface,
          unselectedLabelColor: DragonColors.textDim,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Find', icon: Icon(Icons.search_rounded, size: 17)),
            Tab(
                text: 'Installed',
                icon: Icon(Icons.download_done_rounded, size: 17)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ---------------- find ----------------
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _search,
                  onSubmitted: (_) => _runSearch(),
                  decoration: InputDecoration(
                    hintText: 'Search SKILL.md — e.g. pdf, docx, git…',
                    prefixIcon:
                        Icon(Icons.search_rounded, color: DragonColors.textDim),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                child: Row(
                  children: [
                    Text('Sources:',
                        style: TextStyle(
                            fontSize: 11.5, color: DragonColors.textDim)),
                    const SizedBox(width: 6),
                    for (final s in state.skills.sources)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(s,
                            style: TextStyle(
                                fontSize: 11.5,
                                fontFamily: 'monospace',
                                color: DragonColors.success)),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: _searching ? null : _runSearch,
                      child: const Text('Search'),
                    ),
                  ],
                ),
              ),
              if (_searchError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(_searchError!,
                      style: TextStyle(
                          fontSize: 12, color: DragonColors.emberDeep)),
                ),
              Expanded(
                child: _searching
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: DragonColors.ember))
                    : _hits.isEmpty
                        ? Center(
                            child: Text(
                              'Type a name and search — skills are SKILL.md\n'
                              'files discovered inside the source repos.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(height: 1.6),
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: _hits.length,
                            itemBuilder: (context, i) {
                              final hit = _hits[i];
                              final imported = state.skills.all.any(
                                  (s) => s.repo == hit.repo && s.path == hit.path);
                              final busy = _importing.contains(hit.path);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: dark
                                      ? DragonColors.card
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  child: ListTile(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    leading: Icon(
                                      Icons.description_outlined,
                                      size: 20,
                                      color: imported
                                          ? DragonColors.success
                                          : DragonColors.gold,
                                    ),
                                    title: Text(hit.name,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                    subtitle: Text(
                                      imported
                                          ? 'imported · ${hit.repo}'
                                          : hit.repo,
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          color: DragonColors.textDim),
                                    ),
                                    trailing: imported
                                        ? const Icon(Icons.check_circle_rounded,
                                            color: DragonColors.success,
                                            size: 19)
                                        : busy
                                            ? const SizedBox(
                                                width: 17,
                                                height: 17,
                                                child: CircularProgressIndicator(
                                                    strokeWidth: 2.2,
                                                    color: DragonColors.ember))
                                            : IconButton(
                                                icon: const Icon(
                                                    Icons.download_rounded,
                                                    size: 20),
                                                onPressed: () => _import(hit),
                                              ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
          // ---------------- installed ----------------
          state.skills.all.isEmpty
              ? Center(
                  child: Text(
                    'No skills installed yet.\nImported skills live on this '
                    'device and appear when you type / in chat.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .copyWith(height: 1.6),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  children: [
                    for (final s in state.skills.all)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: dark ? DragonColors.card : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            leading: const Icon(Icons.auto_fix_high_rounded,
                                size: 20, color: DragonColors.gold),
                            title: Text(s.name,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              s.description.isEmpty
                                  ? s.repo
                                  : s.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: DragonColors.textDim),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 19, color: DragonColors.textDim),
                              onPressed: () => state.skills.remove(s.id),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ],
      ),
    );
  }
}
