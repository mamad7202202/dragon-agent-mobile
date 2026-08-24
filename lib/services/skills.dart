import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'memory.dart';

/// One imported SKILL.md.
class LoadedSkill {
  final String id;
  final String name;
  final String description;
  final String repo; // owner/repo it came from
  final String path; // path to the SKILL.md inside the repo
  final String body; // instructions (frontmatter stripped)

  LoadedSkill({
    required this.id,
    required this.name,
    required this.description,
    required this.repo,
    required this.path,
    required this.body,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'repo': repo,
        'path': path,
        'body': body,
      };

  factory LoadedSkill.fromJson(Map<String, dynamic> j) => LoadedSkill(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? 'skill',
        description: j['description'] as String? ?? '',
        repo: j['repo'] as String? ?? '',
        path: j['path'] as String? ?? '',
        body: j['body'] as String? ?? '',
      );
}

/// A hit from searching a source repo for SKILL.md files.
class SkillHit {
  final String repo;
  final String path; // …/SKILL.md
  final String folder; // parent folder name — the skill's slug
  final String name;
  final String description;

  SkillHit({
    required this.repo,
    required this.path,
    required this.folder,
    required this.name,
    required this.description,
  });
}

/// Finds SKILL.md files in trusted GitHub sources, imports them into the app
/// and keeps them on device.
class SkillStore extends ChangeNotifier {
  final http.Client _http = http.Client();

  /// Trusted open-source sources — Anthropic's official skills repo first.
  final List<String> sources = ['anthropics/skills'];

  final List<LoadedSkill> skills = [];

  List<LoadedSkill> get all => List.unmodifiable(skills);

  Future<String> get _dir async => '${await MemoryStore().dirPath}/skills';

  Future<void> load() async {
    final dir = await _dir;
    try {
      final raw = await readFile('$dir/index.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      skills
        ..clear()
        ..addAll(list.map(LoadedSkill.fromJson));
    } catch (_) {}
  }

  Future<void> _persist() async {
    final dir = await _dir;
    await writeFile(
      '$dir/index.json',
      jsonEncode(skills.map((s) => s.toJson()).toList()),
    );
  }

  void addSource(String repo) {
    final r = repo.trim();
    if (r.isEmpty || !r.contains('/')) return;
    if (!sources.contains(r)) {
      sources.add(r);
    }
  }

  /// Searches every source repo for SKILL.md files matching [query].
  /// Empty query lists everything (capped).
  Future<List<SkillHit>> search(String query,
      {void Function(String source, int found)? onSource}) async {
    final q = query.trim().toLowerCase();
    final hits = <SkillHit>[];
    for (final repo in sources) {
      try {
        final info = await _json(
            'https://api.github.com/repos/$repo');
        final branch = info['default_branch'] as String? ?? 'main';
        final tree = await _json(
            'https://api.github.com/repos/$repo/git/trees/$branch?recursive=1');
        final entries = (tree['tree'] as List?) ?? const [];
        var found = 0;
        for (final e in entries) {
          if (e is! Map) continue;
          final path = e['path'] as String? ?? '';
          if (!path.endsWith('SKILL.md')) continue;
          found++;
          final folder = path.split('/').reversed.toList()[1];
          if (q.isNotEmpty &&
              !path.toLowerCase().contains(q) &&
              !folder.toLowerCase().contains(q)) {
            continue;
          }
          if (hits.length >= 40) break;
          // description is unknown until imported — show the folder path
          hits.add(SkillHit(
            repo: repo,
            path: path,
            folder: folder,
            name: folder.replaceAll(RegExp(r'[-_]'), ' '),
            description: '$repo/$path',
          ));
        }
        onSource?.call(repo, found);
      } catch (_) {
        // source unreachable or rate-limited — skip it
      }
    }
    return hits;
  }

  /// Fetches the SKILL.md, parses frontmatter and stores it on device.
  Future<LoadedSkill> import(SkillHit hit) async {
    final res = await _http
        .get(Uri.parse(
            'https://raw.githubusercontent.com/${hit.repo}/HEAD/${hit.path}'))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} while fetching SKILL.md');
    }
    final parsed = _parseFrontmatter(utf8.decode(res.bodyBytes));
    final id = '${hit.repo}/${hit.path}'
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        .toLowerCase();
    final skill = LoadedSkill(
      id: id,
      name: (parsed['name']?.isNotEmpty ?? false)
          ? parsed['name']!
          : hit.name,
      description: parsed['description'] ?? '',
      repo: hit.repo,
      path: hit.path,
      body: parsed['body'] ?? '',
    );
    skills.removeWhere((s) => s.id == id);
    skills.add(skill);
    await _persist();
    notifyListeners();
    return skill;
  }

  Future<void> remove(String id) async {
    skills.removeWhere((s) => s.id == id);
    await _persist();
    notifyListeners();
  }

  LoadedSkill? byId(String id) {
    for (final s in skills) {
      if (s.id == id) return s;
    }
    return null;
  }

  void clearAll() {
    skills.clear();
    notifyListeners();
  }

  /// Minimal YAML frontmatter parser: --- name: … description: … ---
  static Map<String, String> _parseFrontmatter(String raw) {
    final out = <String, String>{};
    var body = raw;
    if (raw.startsWith('---')) {
      final end = raw.indexOf('\n---', 3);
      if (end > 0) {
        final fm = raw.substring(3, end);
        body = raw.substring(end + 4);
        for (final line in fm.split('\n')) {
          final idx = line.indexOf(':');
          if (idx <= 0) continue;
          final key = line.substring(0, idx).trim();
          var value = line.substring(idx + 1).trim();
          if (value.startsWith('"') && value.endsWith('"') && value.length > 1) {
            value = value.substring(1, value.length - 1);
          }
          out[key] = value;
        }
      }
    }
    out['body'] = body.trim();
    return out;
  }

  Future<Map<String, dynamic>> _json(String url) async {
    final res = await _http
        .get(Uri.parse(url), headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) {
      throw Exception('GitHub HTTP ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  @override
  void dispose() {
    _http.close();
    super.dispose();
  }
}
