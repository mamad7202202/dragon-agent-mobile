import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Hybrid memory system — ported from the desktop Dragon Agent.
///
/// 1. Semantic: discrete facts recalled per-turn via lexical cosine scoring
///    blended with importance and a two-week-ish recency decay.
/// 2. Procedural: plain MEMORY.md always injected into the system prompt.
/// 3. Episodic: full session transcripts (handled by SessionStore).
class Fact {
  final String id;
  final String content;
  final List<String> tags;
  double importance; // 0.0 .. 1.0
  final DateTime createdAt;
  int hits;

  Fact({
    required this.id,
    required this.content,
    this.tags = const [],
    this.importance = 0.5,
    required this.createdAt,
    this.hits = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'tags': tags,
        'importance': importance,
        'created_at': createdAt.toIso8601String(),
        'hits': hits,
      };

  factory Fact.fromJson(Map<String, dynamic> j) => Fact(
        id: j['id'] as String? ?? '',
        content: j['content'] as String? ?? '',
        tags: (j['tags'] as List?)?.cast<String>() ?? const [],
        importance: (j['importance'] as num?)?.toDouble() ?? 0.5,
        createdAt:
            DateTime.tryParse(j['created_at'] as String? ?? '') ??
                DateTime.now(),
        hits: (j['hits'] as num?)?.toInt() ?? 0,
      );
}

class MemoryStore {
  static const _uuid = Uuid();
  final List<Fact> _facts = [];
  String _memoryMd = '';
  String? _dirPath;

  List<Fact> get all => List.unmodifiable(_facts);
  String get procedural => _memoryMd;

  Future<String> get dirPath async =>
      _dirPath ??= '${(await getApplicationDocumentsDirectory()).path}/dragon';

  Future<void> load() async {
    final dir = await dirPath;
    try {
      final raw = await readFile('$dir/memory/facts.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _facts
        ..clear()
        ..addAll(list.map(Fact.fromJson));
    } catch (_) {}
    try {
      _memoryMd = await readFile('$dir/memory/MEMORY.md');
    } catch (_) {
      _memoryMd = '';
    }
  }

  Future<void> saveFacts() async {
    final dir = await dirPath;
    await writeFile(
      '$dir/memory/facts.json',
      const JsonEncoder.withIndent('  ')
          .convert(_facts.map((f) => f.toJson()).toList()),
    );
  }

  Future<void> saveProcedural(String md) async {
    _memoryMd = md;
    final dir = await dirPath;
    await writeFile('$dir/memory/MEMORY.md', md);
  }

  /// Adds a fact, de-duplicating near-identical content (refreshes instead).
  Fact add(String content, {double importance = 0.5, List<String> tags = const []}) {
    final norm = normalize(content);
    for (final existing in _facts) {
      if (normalize(existing.content) == norm) {
        existing.importance = math.max(existing.importance, importance);
        for (final t in tags) {
          if (!existing.tags.contains(t)) existing.tags.add(t);
        }
        return existing;
      }
    }
    final fact = Fact(
      id: _uuid.v4().replaceAll('-', '').substring(0, 8),
      content: content.trim(),
      tags: tags,
      importance: importance.clamp(0.0, 1.0),
      createdAt: DateTime.now(),
    );
    _facts.add(fact);
    return fact;
  }

  bool remove(String idPrefix) {
    final before = _facts.length;
    _facts.retainWhere((f) => !f.id.startsWith(idPrefix));
    return before != _facts.length;
  }

  void clear() => _facts.clear();

  /// Recall the most relevant facts blending relevance × importance × recency.
  List<Fact> recall(String query, [int k = 6]) {
    final qTokens = tokenize(query);
    if (qTokens.isEmpty || _facts.isEmpty) return [];
    final now = DateTime.now();
    final scored = <MapEntry<double, int>>[];
    for (var i = 0; i < _facts.length; i++) {
      final fact = _facts[i];
      final text = '${fact.content} ${fact.tags.join(' ')}'.toLowerCase();
      final rel = cosine(qTokens, tokenize(text));
      if (rel <= 0) continue;
      final ageDays =
          now.difference(fact.createdAt).inDays.clamp(0, 1 << 30).toDouble();
      final recency = 1.0 / (1.0 + ageDays / 14.0);
      final score = rel * (0.55 + 0.45 * fact.importance) * (0.7 + 0.3 * recency);
      scored.add(MapEntry(score, i));
    }
    scored.sort((a, b) => b.key.compareTo(a.key));
    final out = <Fact>[];
    for (final e in scored.take(k)) {
      _facts[e.value].hits += 1;
      out.add(_facts[e.value]);
    }
    return out;
  }

  /// Rendered block injected into the system prompt, or null.
  String? recallBlock(String query, [int k = 6]) {
    final facts = recall(query, k);
    if (facts.isEmpty) return null;
    final buf = StringBuffer('[REMEMBERED FACTS]\n');
    for (final f in facts) {
      buf.writeln('- ${f.content}');
    }
    return buf.toString();
  }

  String? proceduralBlock() {
    if (_memoryMd.trim().isEmpty) return null;
    final trimmed = _memoryMd.runes.take(6000).map(String.fromCharCode).join();
    return '[PROCEDURAL MEMORY - persistent user instructions]\n$trimmed';
  }
}

String normalize(String s) =>
    s.toLowerCase().trim().split(RegExp(r'\s+')).join(' ');

List<String> tokenize(String s) => s
    .split(RegExp(r'[^a-zA-Z0-9\u0600-\u06FF]+'))
    .where((t) => t.length > 1 && t.length < 24)
    .toList();

double cosine(List<String> a, List<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  final ca = <String, double>{};
  for (final t in a) {
    ca[t] = (ca[t] ?? 0) + 1;
  }
  final cb = <String, double>{};
  for (final t in b) {
    cb[t] = (cb[t] ?? 0) + 1;
  }
  var dot = 0.0;
  ca.forEach((t, va) {
    dot += va * (cb[t] ?? 0);
  });
  var na = 0.0;
  for (final v in ca.values) {
    na += v * v;
  }
  var nb = 0.0;
  for (final v in cb.values) {
    nb += v * v;
  }
  na = math.sqrt(na);
  nb = math.sqrt(nb);
  if (na == 0 || nb == 0) return 0;
  return dot / (na * nb);
}

// ---- file helpers ----

Future<String> readFile(String path) => File(path).readAsString();

Future<void> writeFile(String path, String content) async {
  final f = File(path);
  await f.parent.create(recursive: true);
  await f.writeAsString(content);
}

Future<bool> existsFile(String path) => File(path).exists();

Future<List<String>> listDir(String path) async {
  final d = Directory(path);
  if (!d.existsSync()) return [];
  return d.listSync().map((e) => e.path).toList();
}

Future<void> deleteFile(String path) async {
  final f = File(path);
  if (f.existsSync()) await f.delete();
}
