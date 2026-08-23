import 'dart:convert';

import 'package:path_provider/path_provider.dart';

import 'memory.dart';
import 'models.dart';

/// Episodic memory — one JSON transcript per session, resumable verbatim.
class SessionMeta {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;

  SessionMeta({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class SessionStore {
  final List<SessionMeta> metas = [];

  Future<String> get sessionsDir async =>
      '${(await getApplicationDocumentsDirectory()).path}/dragon/sessions';

  static final _uuid = Uuid2();

  Future<void> loadIndex() async {
    final dir = await sessionsDir;
    metas.clear();
    for (final path in await listDir(dir)) {
      if (!path.endsWith('.json')) continue;
      try {
        final raw = await readFile(path);
        final j = jsonDecode(raw) as Map<String, dynamic>;
        final wire = (j['wire'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final meta = SessionMeta(
          id: j['id'] as String,
          title: (j['title'] as String?) ?? sessionTitleFromWire(wire),
          createdAt: DateTime.parse(j['created_at'] as String),
          updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? '') ??
              DateTime.now(),
        );
        metas.add(meta);
      } catch (_) {}
    }
    metas.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<SessionData> create() async {
    final s = SessionData(
      id: _uuid.v4().replaceAll('-', '').substring(0, 12),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return s;
  }

  Future<SessionData> open(String id) async {
    final path = '${await sessionsDir}/$id.json';
    final raw = await readFile(path);
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return SessionData.fromJson(j);
  }

  Future<void> persist(SessionData s) async {
    s.updatedAt = DateTime.now();
    final path = '${await sessionsDir}/${s.id}.json';
    await writeFile(path, jsonEncode(s.toJson()));
    final existing = metas.where((m) => m.id == s.id).firstOrNull;
    final title = sessionTitleFromWire(s.wire);
    if (existing != null) {
      existing
        ..title = title
        ..updatedAt = s.updatedAt;
    } else {
      metas.insert(
        0,
        SessionMeta(
          id: s.id,
          title: title,
          createdAt: s.createdAt,
          updatedAt: s.updatedAt,
        ),
      );
    }
    metas.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> delete(String id) async {
    metas.removeWhere((m) => m.id == id);
    try {
      await deleteFile('${await sessionsDir}/$id.json');
    } catch (_) {}
  }
}

/// A full resumable session.
class SessionData {
  final String id;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<Map<String, dynamic>> wire;

  SessionData({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    List<Map<String, dynamic>>? wire,
  }) : wire = wire ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': sessionTitleFromWire(wire),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'wire': wire,
      };

  factory SessionData.fromJson(Map<String, dynamic> j) => SessionData(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt:
            DateTime.tryParse(j['updated_at'] as String? ?? '') ??
                DateTime.now(),
        wire: (j['wire'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [],
      );

  bool get isEmptyConversation =>
      !wire.any((m) => m['r'] == 'u' || m['r'] == 'a');
}

class Uuid2 {
  final _r = DateTime.now().microsecondsSinceEpoch;
  var _c = 0;
  String v4() {
    _c++;
    return '$_r$_c'.padLeft(16, '0') + (_r % 9973).toString();
  }
}
