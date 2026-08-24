import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// One configured MCP (Model Context Protocol) server — a "skill" source.
class McpServerCfg {
  final String id;
  String name;
  String url;
  String token;
  bool enabled;

  McpServerCfg({
    required this.id,
    required this.name,
    required this.url,
    this.token = '',
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'token': token,
        'enabled': enabled,
      };

  factory McpServerCfg.fromJson(Map<String, dynamic> j) => McpServerCfg(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? 'server',
        url: j['url'] as String? ?? '',
        token: j['token'] as String? ?? '',
        enabled: j['enabled'] as bool? ?? true,
      );
}

/// A tool advertised by an MCP server.
class McpToolInfo {
  final String name;
  final String description;
  final Map<String, dynamic> schema;

  McpToolInfo({
    required this.name,
    required this.description,
    required this.schema,
  });
}

class McpException implements Exception {
  final String message;
  McpException(this.message);
  @override
  String toString() => message;
}

/// Live connection to one MCP server over Streamable HTTP (JSON-RPC 2.0).
class McpConnection {
  final McpServerCfg cfg;
  final http.Client _http = http.Client();
  String? _sessionId;
  var _nextId = 1;

  McpConnection(this.cfg);

  void close() => _http.close();

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/event-stream',
        if (cfg.token.trim().isNotEmpty) 'Authorization': 'Bearer ${cfg.token.trim()}',
        if (_sessionId != null) 'Mcp-Session-Id': _sessionId!,
      };

  /// Sends one JSON-RPC request; returns result map, or null for 202 notices.
  Future<Map<String, dynamic>?> _rpc(String method,
      [Map<String, dynamic>? params]) async {
    final id = _nextId++;
    final body = {
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    };

    http.StreamedResponse res;
    try {
      final req = http.Request('POST', Uri.parse(cfg.url))
        ..headers.addAll(_headers())
        ..body = jsonEncode(body);
      res = await _http.send(req).timeout(const Duration(seconds: 25));
    } catch (e) {
      throw McpException('$method failed: $e');
    }

    final sid = res.headers['mcp-session-id'];
    if (sid != null && sid.isNotEmpty) _sessionId = sid;

    if (res.statusCode == 202) return null;
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw McpException('unauthorized — check the server token');
    }
    if (res.statusCode != 200) {
      final body = await res.stream.bytesToString();
      throw McpException('HTTP ${res.statusCode} · ${_clip(body, 160)}');
    }

    final text = await res.stream.bytesToString();
    final ct = (res.headers['content-type'] ?? '').toLowerCase();
    Map<String, dynamic>? msg;
    if (ct.contains('text/event-stream')) {
      msg = _lastSseMessage(text, id);
    } else {
      try {
        msg = jsonDecode(text) as Map<String, dynamic>;
      } catch (_) {
        throw McpException('unparseable response from $method');
      }
    }
    if (msg == null) return null;
    if (msg['error'] is Map) {
      final e = msg['error'] as Map;
      throw McpException('${e['code']} · ${e['message']}');
    }
    return msg['result'] as Map<String, dynamic>?;
  }

  Map<String, dynamic>? _lastSseMessage(String text, int wantId) {
    Map<String, dynamic>? found;
    for (final line in text.split('\n')) {
      final l = line.trim();
      if (!l.startsWith('data:')) continue;
      try {
        final j = jsonDecode(l.substring(5).trim()) as Map<String, dynamic>;
        if (j.containsKey('result') || j.containsKey('error')) {
          final jid = j['id'];
          if (jid == wantId || jid == null) found = j;
        }
      } catch (_) {}
    }
    return found;
  }

  Future<void> initialize() async {
    final result = await _rpc('initialize', {
      'protocolVersion': '2025-03-26',
      'capabilities': <String, dynamic>{},
      'clientInfo': {'name': 'dragon-agent-mobile', 'version': '1.3.0'},
    });
    if (result == null) throw McpException('no response to initialize');
    try {
      await _rpc('notifications/initialized');
    } catch (_) {}
  }

  Future<List<McpToolInfo>> listTools() async {
    var result = await _rpc('tools/list');
    if (result == null) {
      // some servers answer only on a later retry once initialized
      result = await _rpc('tools/list');
    }
    final tools = (result?['tools'] as List?) ?? const [];
    return tools.map((t) {
      final m = t as Map<String, dynamic>;
      return McpToolInfo(
        name: m['name'] as String? ?? '',
        description: (m['description'] as String?) ?? '',
        schema: (m['inputSchema'] as Map?)?.cast<String, dynamic>() ??
            {'type': 'object', 'properties': <String, dynamic>{}},
      );
    }).toList();
  }

  Future<String> callTool(String name, Map<String, dynamic> arguments) async {
    final result = await _rpc('tools/call', {
      'name': name,
      'arguments': arguments,
    });
    if (result == null) throw McpException('empty tool result');
    final isError = result['isError'] as bool? ?? false;
    final content = (result['content'] as List?) ?? const [];
    final buf = StringBuffer();
    for (final block in content) {
      if (block is Map && block['type'] == 'text') {
        buf.writeln(block['text'] ?? '');
      } else if (block is Map) {
        buf.writeln(jsonEncode(block));
      }
    }
    final out = buf.toString().trim();
    if (isError) throw McpException(out.isEmpty ? 'tool error' : _clip(out, 300));
    return out;
  }

  String _clip(String s, int n) => s.length <= n ? s : '${s.substring(0, n)}…';
}

/// Known skill sources offered in the UI.
const mcpPresets = <Map<String, String>>[
  {
    'id': 'github',
    'name': 'GitHub',
    'url': 'https://api.githubcopilot.com/mcp',
    'hint': 'GitHub PAT — repos, issues, PRs, actions, files',
  },
  {
    'id': 'cloudflare-docs',
    'name': 'Cloudflare Docs',
    'url': 'https://docs.mcp.cloudflare.com/mcp',
    'hint': 'Cloudflare platform documentation',
  },
  {
    'id': 'custom',
    'name': 'Custom MCP server',
    'url': '',
    'hint': 'Any Streamable-HTTP MCP endpoint',
  },
];

/// Registry of all configured servers + their tools, persisted in prefs.
class McpRegistry extends ChangeNotifier {
  final List<McpServerCfg> servers = [];
  final Map<String, List<McpToolInfo>> _tools = {};
  final Map<String, String> errors = {};
  final Map<String, (String, String)> _routes = {}; // llmName → (serverId, tool)
  final http.Client _http = http.Client();
  bool refreshing = false;

  List<McpServerCfg> get enabledServers =>
      servers.where((s) => s.enabled).toList();
  int get totalTools => _routes.length;
  int get enabledCount => enabledServers.length;
  bool get hasEnabled => enabledServers.isNotEmpty;

  List<McpToolInfo> toolsOf(String serverId) => _tools[serverId] ?? const [];

  void load(String? raw) {
    servers.clear();
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      servers.addAll(list
          .map((e) => McpServerCfg.fromJson(Map<String, dynamic>.from(e as Map))));
    } catch (_) {}
  }

  String persist() => jsonEncode(servers.map((s) => s.toJson()).toList());

  Future<void> refreshAll() async {
    if (refreshing) return;
    refreshing = true;
    notifyListeners();
    for (final s in enabledServers) {
      try {
        await refreshServer(s);
      } catch (_) {}
    }
    refreshing = false;
    notifyListeners();
  }

  Future<List<McpToolInfo>> refreshServer(McpServerCfg cfg) async {
    final conn = McpConnection(cfg);
    try {
      await conn.initialize();
      final tools = await conn.listTools();
      _tools[cfg.id] = tools;
      errors.remove(cfg.id);
      _rebuildRoutes();
      notifyListeners();
      return tools;
    } on McpException catch (e) {
      errors[cfg.id] = e.message;
      _tools.remove(cfg.id);
      _rebuildRoutes();
      notifyListeners();
      rethrow;
    } finally {
      conn.close();
    }
  }

  void _rebuildRoutes() {
    _routes.clear();
    for (final s in enabledServers) {
      final key = _serverKey(s);
      for (final t in _tools[s.id] ?? const <McpToolInfo>[]) {
        final llmName = 'mcp_${key}_${_sanitize(t.name)}';
        if (llmName.length <= 64) {
          _routes[llmName] = (s.id, t.name);
        }
      }
    }
  }

  String _serverKey(McpServerCfg s) {
    final k = _sanitize(s.name.toLowerCase());
    return k.length <= 8 ? k : k.substring(0, 8);
  }

  String _sanitize(String s) =>
      s.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_').toLowerCase();

  /// OpenAI-style tool definitions for the LLM, namespaced per server.
  List<Map<String, Object>> toolDefsForLlm({int max = 26}) {
    final defs = <Map<String, Object>>[];
    for (final s in enabledServers) {
      for (final t in _tools[s.id] ?? const <McpToolInfo>[]) {
        final llmName = 'mcp_${_serverKey(s)}_${_sanitize(t.name)}';
        if (!_routes.containsKey(llmName)) continue;
        defs.add({
          'name': llmName,
          'description': '[${s.name}] ${t.description}'.trim(),
          'parameters': t.schema,
        });
        if (defs.length >= max) return defs;
      }
    }
    return defs;
  }

  /// True when [toolName] belongs to an MCP server.
  bool isMcpTool(String toolName) => _routes.containsKey(toolName);

  /// Executes a namespaced MCP tool; returns the text result.
  Future<String> call(String llmName, Map<String, dynamic> arguments) async {
    final route = _routes[llmName];
    if (route == null) throw McpException('unknown tool $llmName');
    final server = servers.firstWhere((s) => s.id == route.$1);
    final conn = McpConnection(server);
    try {
      await conn.initialize();
      return await conn.callTool(route.$2, arguments);
    } finally {
      conn.close();
    }
  }

  McpServerCfg add(McpServerCfg cfg) {
    servers.add(cfg);
    notifyListeners();
    return cfg;
  }

  void remove(String id) {
    servers.removeWhere((s) => s.id == id);
    _tools.remove(id);
    errors.remove(id);
    _rebuildRoutes();
    notifyListeners();
  }

  void clearAll() {
    servers.clear();
    _tools.clear();
    errors.clear();
    _routes.clear();
    notifyListeners();
  }

  void setEnabled(McpServerCfg cfg, bool enabled) {
    cfg.enabled = enabled;
    _rebuildRoutes();
    notifyListeners();
  }

  void dispose() {
    _http.close();
    super.dispose();
  }
}
