import 'dart:convert';

import 'memory.dart';

/// One bullet inside a memory section.
class GraphEntry {
  final String id;
  String text;
  DateTime updated;

  GraphEntry({required this.id, required this.text, required this.updated});

  Map<String, dynamic> toJson() =>
      {'id': id, 'text': text, 'u': updated.toIso8601String()};

  factory GraphEntry.fromJson(Map<String, dynamic> j) => GraphEntry(
        id: j['id'] as String? ?? '',
        text: j['text'] as String? ?? '',
        updated: DateTime.tryParse(j['u'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Outline ("infographic") memory — hierarchical sections of short bullets.
///
/// Designed so the model can hold the whole memory in a few hundred tokens:
/// every entry is a self-contained one-liner under a named section.
class GraphMemoryStore {
  static const defaultSections = [
    'profile',
    'preferences',
    'projects',
    'people',
    'goals',
    'facts',
  ];

  final Map<String, List<GraphEntry>> sections = {};
  var _counter = 0;

  int get entryCount =>
      sections.values.fold(0, (sum, list) => sum + list.length);
  int get sectionCount =>
      sections.values.where((s) => s.isNotEmpty).length;

  Future<void> load() async {
    final dir = await MemoryStore().dirPath;
    try {
      final raw = await readFile('$dir/memory/graph_memory.json');
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final secs = j['sections'] as Map<String, dynamic>? ?? {};
      sections.clear();
      secs.forEach((name, list) {
        sections[name] = (list as List)
            .map((e) => GraphEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });
    } catch (_) {}
  }

  Future<void> save() async {
    final dir = await MemoryStore().dirPath;
    await writeFile(
      '$dir/memory/graph_memory.json',
      jsonEncode({
        'sections': sections.map(
          (name, list) => MapEntry(name, list.map((e) => e.toJson()).toList()),
        ),
      }),
    );
  }

  String _newId() {
    _counter = (_counter + 1) % 46656;
    final ts = DateTime.now().millisecondsSinceEpoch
        .toRadixString(36)
        .substring(5);
    return '$ts${_counter.toRadixString(36).padLeft(3, '0')}';
  }

  /// Upserts bullets into [section]. Dedupes identical content.
  /// Returns the list of ids written (same order as [bullets]).
  List<String> write(String section, List<String> bullets) {
    final name = _normSection(section);
    final list = sections.putIfAbsent(name, () => []);
    final ids = <String>[];
    for (final raw in bullets) {
      var text = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (text.isEmpty) continue;
      if (text.length > 160) text = '${text.substring(0, 157)}…';
      final norm = text.toLowerCase();
      final existing = list
          .where((e) => e.text.toLowerCase() == norm)
          .toList();
      if (existing.isNotEmpty) {
        existing.first.updated = DateTime.now();
        ids.add(existing.first.id);
        continue;
      }
      // near-duplicate: same section & 90% prefix overlap → refresh
      final near = list.where((e) {
        final a = e.text.toLowerCase();
        final shorter = a.length < norm.length ? a : norm;
        final longer = a.length < norm.length ? norm : a;
        return longer.startsWith(shorter) && shorter.length > 12;
      }).toList();
      if (near.isNotEmpty) {
        near.first.text = text;
        near.first.updated = DateTime.now();
        ids.add(near.first.id);
        continue;
      }
      final entry = GraphEntry(
          id: _newId(), text: text, updated: DateTime.now());
      list.add(entry);
      ids.add(entry.id);
    }
    return ids;
  }

  /// Delete by entry id prefix, or clear a whole [section]. Returns true when
  /// something was removed.
  bool remove({String? id, String? section}) {
    if (section != null && section.trim().isNotEmpty) {
      final name = _normSection(section);
      final had = sections[name]?.isNotEmpty ?? false;
      sections[name] = [];
      return had;
    }
    if (id == null || id.trim().isEmpty) return false;
    final prefix = id.trim().toLowerCase();
    var removed = false;
    sections.forEach((_, list) {
      final before = list.length;
      list.removeWhere((e) => e.id.toLowerCase().startsWith(prefix));
      if (list.length != before) removed = true;
    });
    return removed;
  }

  /// Compact outline for prompt injection. When [query] is given, sections are
  /// ranked by lexical overlap so the most relevant ones survive truncation.
  String outline({String? query, int maxChars = 1800}) {
    if (sections.isEmpty) return '';
    final names = sections.keys.toList()
      ..sort((a, b) => _sectionScore(b, query).compareTo(_sectionScore(a, query)));

    final buf = StringBuffer('[MEMORY OUTLINE]\n');
    var used = 0;
    var wroteAny = false;
    for (final name in names) {
      final list = sections[name];
      if (list == null || list.isEmpty) continue;
      final line = StringBuffer('$name:');
      for (final e in list) {
        final piece = ' ${e.text};';
        if (used + line.length + piece.length > maxChars && wroteAny) break;
        line.write(piece);
      }
      final s = '$line\n';
      if (used + s.length > maxChars) {
        if (!wroteAny) {
          // always include at least one (truncated) section
          buf.write(s.length > maxChars
              ? '${s.substring(0, maxChars)}…\n'
              : s);
        }
        break;
      }
      buf.write(s);
      used += s.length;
      wroteAny = true;
    }
    return buf.toString().trim();
  }

  double _sectionScore(String name, String? query) {
    if (query == null || query.trim().isEmpty) return 0;
    final q = tokenize(query.toLowerCase());
    final n = tokenize(name.toLowerCase());
    return cosine(q, n);
  }

  /// Flat listing for the list_memories tool / manager UI.
  String listAll() {
    if (sections.isEmpty) return '(memory is empty)';
    final buf = StringBuffer();
    sections.forEach((name, list) {
      if (list.isEmpty) return;
      buf.writeln('# $name');
      for (final e in list) {
        buf.writeln('- (${e.id}) ${e.text}');
      }
    });
    return buf.toString().trim();
  }

  String _normSection(String s) {
    var n = s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    if (n.isEmpty) n = 'facts';
    return n;
  }
}
