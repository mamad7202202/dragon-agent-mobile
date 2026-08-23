import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../core/presets.dart';
import 'models.dart';

/// Deep-thinking (reasoning) effort level.
enum ThinkingLevel { off, low, medium, high }

extension ThinkingLevelX on ThinkingLevel {
  String get label => switch (this) {
        ThinkingLevel.off => 'Off',
        ThinkingLevel.low => 'Low',
        ThinkingLevel.medium => 'Medium',
        ThinkingLevel.high => 'Deep',
      };

  String get wireName => switch (this) {
        ThinkingLevel.low => 'low',
        ThinkingLevel.medium => 'medium',
        _ => 'high',
      };

  int get anthropicBudget => switch (this) {
        ThinkingLevel.low => 2048,
        ThinkingLevel.medium => 8192,
        _ => 16384,
      };
}

/// One provider configuration (key + endpoint + model).
class ProviderCfg {
  String name;
  String baseUrl;
  Protocol protocol;
  String apiKey;
  List<String> models;

  ProviderCfg({
    required this.name,
    required this.baseUrl,
    required this.protocol,
    required this.apiKey,
    this.models = const [],
  });

  bool get supportsWebSearch =>
      protocol == Protocol.anthropic || baseUrl.contains('openrouter');

  Map<String, dynamic> toJson() => {
        'name': name,
        'base_url': baseUrl,
        'protocol': protocol == Protocol.anthropic ? 'anthropic' : 'openai',
        'api_key': apiKey,
        'models': models,
      };

  factory ProviderCfg.fromJson(Map<String, dynamic> j) => ProviderCfg(
        name: j['name'] as String? ?? 'custom',
        baseUrl: j['base_url'] as String? ?? '',
        protocol:
            j['protocol'] == 'anthropic' ? Protocol.anthropic : Protocol.openai,
        apiKey: j['api_key'] as String? ?? '',
        models: (j['models'] as List?)?.cast<String>() ?? const [],
      );
}

class ToolCall {
  final String id;
  final String name;
  final String argsJson;
  ToolCall({required this.id, required this.name, required this.argsJson});
}

/// Events emitted while a turn runs.
sealed class TurnEvent {}

final class DeltaText extends TurnEvent {
  final String text;
  DeltaText(this.text);
}

final class DeltaThinking extends TurnEvent {
  final String text;
  DeltaThinking(this.text);
}

final class UsageReported extends TurnEvent {
  final MsgUsage usage;
  UsageReported(this.usage);
}

final class ToolRequested extends TurnEvent {
  final ToolCall call;
  ToolRequested(this.call);
}

class LlmException implements Exception {
  final String message;
  LlmException(this.message);
  @override
  String toString() => message;
}

const _memoryToolDefs = [
  {
    'name': 'save_memory',
    'description':
        'Persist a durable fact about the user, project or conversation for '
            'future sessions. Call whenever you notice something worth keeping.',
    'parameters': {
      'type': 'object',
      'properties': {
        'text': {'type': 'string', 'description': 'The fact, one sentence.'},
        'importance': {
          'type': 'number',
          'description': '0.0-1.0, how much it matters. Default 0.5.'
        },
      },
      'required': ['text'],
    },
  },
  {
    'name': 'forget_memory',
    'description': 'Delete a previously saved fact by its id prefix.',
    'parameters': {
      'type': 'object',
      'properties': {
        'id': {'type': 'string', 'description': 'Fact id or id prefix.'},
      },
      'required': ['id'],
    },
  },
];

const _outlineToolDefs = [
  {
    'name': 'memory_write',
    'description':
        'Upsert one or more short bullets into a section of the user memory '
            'outline (profile, preferences, projects, people, goals, facts...). '
            'Bullets must be self-contained, max ~140 chars. Existing identical '
            'bullets are refreshed instead of duplicated.',
    'parameters': {
      'type': 'object',
      'properties': {
        'section': {
          'type': 'string',
          'description': 'Section name, e.g. "profile", "preferences".'
        },
        'bullets': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'One or more concise bullets to store.'
        },
      },
      'required': ['section', 'bullets'],
    },
  },
  {
    'name': 'memory_delete',
    'description': 'Delete an entry from the memory outline by its id prefix, '
        'or clear an entire section with section=...',
    'parameters': {
      'type': 'object',
      'properties': {
        'id': {'type': 'string', 'description': 'Entry id or id prefix.'},
        'section': {
          'type': 'string',
          'description': 'Alternatively, a whole section to clear.'
        },
      },
    },
  },
];

const _extraToolDefs = [
  {
    'name': 'datetime',
    'description':
        'Get the current local date & time and timezone. Use it whenever the '
            'user mentions "today", deadlines, or relative times.',
    'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
  },
  {
    'name': 'calculator',
    'description':
        'Evaluate an arithmetic expression exactly (+ - * / % ^ parentheses). '
            'Use for any non-trivial math instead of mental arithmetic.',
    'parameters': {
      'type': 'object',
      'properties': {
        'expression': {'type': 'string', 'description': 'e.g. (1250*12)/3'},
      },
      'required': ['expression'],
    },
  },
  {
    'name': 'list_memories',
    'description':
        'List everything currently stored in long-term memory (ids + content) '
            'so you can decide what to update or forget.',
    'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
  },
  {
    'name': 'device_info',
    'description':
        'Basic facts about the device the user is on (OS, version, locale, '
            'timezone). Useful for tailoring answers.',
    'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
  },
  {
    'name': 'remember_rule',
    'description':
        'Add a standing rule to the user\'s MEMORY.md — persistent '
            'instructions that are always in effect (e.g. "always answer in '
            'Persian"). Sensitive: asks the user for approval.',
    'parameters': {
      'type': 'object',
      'properties': {
        'rule': {'type': 'string', 'description': 'One rule, one line.'},
      },
      'required': ['rule'],
    },
  },
];

class LlmClient {
  final http.Client _http = http.Client();

  void dispose() => _http.close();

  // ------------------------------------------------------------------
  // Streaming turn
  // ------------------------------------------------------------------

  Future<void> streamTurn({
    required ProviderCfg cfg,
    required String model,
    required String system,
    required List<Map<String, dynamic>> wire,
    double temperature = 0.7,
    int maxTokens = 2048,
    ThinkingLevel thinking = ThinkingLevel.off,
    bool webSearch = false,
    required List<Map<String, Object>> toolDefs,
    required void Function(TurnEvent) onEvent,
  }) async {
    switch (cfg.protocol) {
      case Protocol.openai:
        await _streamOpenAI(cfg, model, system, wire, temperature, maxTokens,
            thinking, webSearch, toolDefs, onEvent);
      case Protocol.anthropic:
        await _streamAnthropic(cfg, model, system, wire, temperature, maxTokens,
            thinking, webSearch, toolDefs, onEvent);
    }
  }

  /// Non-streaming completion — used for compaction summaries.
  Future<String> complete({
    required ProviderCfg cfg,
    required String model,
    required String system,
    required List<Map<String, dynamic>> wire,
    int maxTokens = 700,
  }) async {
    final buf = StringBuffer();
    if (cfg.protocol == Protocol.anthropic) {
      final res = await _post(
        '${_trim(cfg.baseUrl)}/messages',
        headers: {
          'x-api-key': cfg.apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'system': system,
          'max_tokens': maxTokens,
          'messages': _anthropicMessages(wire),
        }),
      );
      final data = jsonDecode(utf8.decode(res));
      for (final block in (data['content'] as List? ?? [])) {
        if (block is Map && block['type'] == 'text') {
          buf.write(block['text'] ?? '');
        }
      }
      return buf.toString();
    }

    final res = await _post(
      '${_trim(cfg.baseUrl)}/chat/completions',
      headers: _openAIHeaders(cfg),
      body: jsonEncode({
        'model': model,
        'messages': _openAIMessages(system, wire),
        'temperature': 0.3,
        'max_tokens': maxTokens,
      }),
    );
    final data = jsonDecode(utf8.decode(res));
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw LlmException('Empty completion response');
    }
    return ((choices.first as Map)['message']
        as Map?)?['content'] as String? ??
        '';
  }

  // ------------------------------------------------------------------
  // OpenAI-compatible
  // ------------------------------------------------------------------

  Map<String, String> _openAIHeaders(ProviderCfg cfg) {
    final h = <String, String>{
      'content-type': 'application/json',
      if (cfg.apiKey.isNotEmpty) 'Authorization': 'Bearer ${cfg.apiKey}',
    };
    if (cfg.baseUrl.contains('openrouter')) {
      h['HTTP-Referer'] = 'https://github.com/mamad7202202/dragon-agent-mobile';
      h['X-Title'] = 'Dragon Agent Mobile';
    }
    return h;
  }

  List<Map<String, dynamic>> _openAIMessages(
      String system, List<Map<String, dynamic>> wire) {
    final out = <Map<String, dynamic>>[
      {'role': 'system', 'content': system},
    ];
    for (final m in wire) {
      switch (m['r'] as String) {
        case 'u':
          out.add({'role': 'user', 'content': m['c']});
        case 'a':
          out.add({'role': 'assistant', 'content': m['c']});
        case 's':
          out.add({
            'role': 'user',
            'content': '[Earlier conversation, summarized]\n${m['c']}'
          });
        case 'at':
          out.add({
            'role': 'assistant',
            'content': null,
            'tool_calls': (m['t'] as List).map((t) {
              final tm = t as Map<String, dynamic>;
              return {
                'id': tm['id'],
                'type': 'function',
                'function': {'name': tm['name'], 'arguments': tm['args']},
              };
            }).toList(),
          });
        case 'tr':
          for (final x in (m['x'] as List)) {
            final xm = x as Map<String, dynamic>;
            out.add(
                {'role': 'tool', 'tool_call_id': xm['id'], 'content': xm['out']});
          }
      }
    }
    return out;
  }

  Future<void> _streamOpenAI(
    ProviderCfg cfg,
    String model,
    String system,
    List<Map<String, dynamic>> wire,
    double temperature,
    int maxTokens,
    ThinkingLevel thinking,
    bool webSearch,
    List<Map<String, Object>> toolDefs,
    void Function(TurnEvent) onEvent,
  ) async {
    var effectiveModel = model;
    if (webSearch && cfg.baseUrl.contains('openrouter')) {
      if (!effectiveModel.contains(':online')) {
        effectiveModel = '$effectiveModel:online';
      }
    }

    final body = <String, dynamic>{
      'model': effectiveModel,
      'messages': _openAIMessages(system, wire),
      'temperature': temperature,
      'max_tokens': maxTokens,
      'stream': true,
      'tools': toolDefs
          .map((t) => {
                'type': 'function',
                'function': t,
              })
          .toList(),
      if (thinking != ThinkingLevel.off) 'reasoning_effort': thinking.wireName,
      if (cfg.baseUrl.contains('api.openai.com'))
        'stream_options': {'include_usage': true},
    };

    final req = http.Request('POST', Uri.parse('${_trim(cfg.baseUrl)}/chat/completions'))
      ..headers.addAll(_openAIHeaders(cfg))
      ..body = jsonEncode(body);

    final res = await _http.send(req);
    if (res.statusCode != 200) {
      throw LlmException(await _errorText(res, 'OpenAI'));
    }

    final calls = <int, ToolCall>{};
    final argsBuf = <int, StringBuffer>{};

    await for (final line in res.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final l = line.trim();
      if (!l.startsWith('data:')) continue;
      final payload = l.substring(5).trim();
      if (payload == '[DONE]') break;
      Map<String, dynamic> j;
      try {
        j = jsonDecode(payload) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }

      final usage = j['usage'] as Map?;
      if (usage != null) {
        onEvent(UsageReported(MsgUsage(
          inputTokens: (usage['prompt_tokens'] as num?)?.toInt() ?? 0,
          outputTokens: (usage['completion_tokens'] as num?)?.toInt() ?? 0,
          totalTokens: (usage['total_tokens'] as num?)?.toInt() ?? 0,
        )));
      }

      final choices = j['choices'] as List?;
      if (choices == null || choices.isEmpty) continue;
      final delta = (choices.first as Map)['delta'] as Map? ?? {};

      final reasoning =
          (delta['reasoning'] ?? delta['reasoning_content']) as String?;
      if (reasoning != null && reasoning.isNotEmpty) {
        onEvent(DeltaThinking(reasoning));
      }

      final content = delta['content'] as String?;
      if (content != null && content.isNotEmpty) {
        onEvent(DeltaText(content));
      }

      final tcs = delta['tool_calls'] as List?;
      if (tcs != null) {
        for (var i = 0; i < tcs.length; i++) {
          final tc = (tcs[i] as Map);
          final idx = (tc['index'] as num?)?.toInt() ?? i;
          final fn = tc['function'] as Map? ?? {};
          if (tc['id'] != null) {
            calls[idx] = ToolCall(
              id: tc['id'] as String,
              name: (fn['name'] as String?) ?? '',
              argsJson: '',
            );
          } else if (calls[idx] != null && fn['name'] != null) {
            calls[idx] = ToolCall(
              id: calls[idx]!.id,
              name: fn['name'] as String,
              argsJson: calls[idx]!.argsJson,
            );
          }
          final frag = fn['arguments'] as String?;
          if (frag != null) {
            (argsBuf[idx] ??= StringBuffer()).write(frag);
          }
        }
      }
    }

    for (final e in argsBuf.entries) {
      final c = calls[e.key];
      if (c != null) {
        calls[e.key] = ToolCall(
            id: c.id, name: c.name, argsJson: e.value.toString());
      }
    }

    for (final c in calls.values) {
      if (c.name.isEmpty) continue;
      onEvent(ToolRequested(c));
    }
  }

  // ------------------------------------------------------------------
  // Anthropic-native
  // ------------------------------------------------------------------

  List<Map<String, dynamic>> _anthropicMessages(
      List<Map<String, dynamic>> wire) {
    final conv = <Map<String, dynamic>>[];
    for (final m in wire) {
      switch (m['r'] as String) {
        case 'u':
          conv.add({'role': 'user', 'content': m['c']});
        case 's':
          conv.add({
            'role': 'user',
            'content': '[Earlier conversation, summarized]\n${m['c']}'
          });
        case 'a':
          conv.add({'role': 'assistant', 'content': m['c']});
        case 'at':
          conv.add({
            'role': 'assistant',
            'content': (m['t'] as List).map((t) {
              final tm = t as Map<String, dynamic>;
              Object input;
              try {
                input = tm['args'].toString().trim().isEmpty
                    ? <String, dynamic>{}
                    : jsonDecode(tm['args'].toString()) as Object;
              } catch (_) {
                input = <String, dynamic>{};
              }
              return {
                'type': 'tool_use',
                'id': tm['id'],
                'name': tm['name'],
                'input': input,
              };
            }).toList(),
          });
        case 'tr':
          conv.add({
            'role': 'user',
            'content': (m['x'] as List).map((x) {
              final xm = x as Map<String, dynamic>;
              return {
                'type': 'tool_result',
                'tool_use_id': xm['id'],
                'content': xm['out'],
              };
            }).toList(),
          });
      }
    }
    final merged = <Map<String, dynamic>>[];
    for (final m in conv) {
      if (merged.isNotEmpty &&
          merged.last['role'] == m['role'] &&
          merged.last['content'] is String &&
          m['content'] is String) {
        merged.last['content'] =
            '${merged.last['content']}\n\n${m['content']}';
      } else if (merged.isNotEmpty &&
          merged.last['role'] == m['role'] &&
          merged.last['content'] is List &&
          m['content'] is List) {
        (merged.last['content'] as List).addAll(m['content'] as List);
      } else {
        merged.add(Map<String, dynamic>.from(m));
      }
    }
    if (merged.isEmpty || merged.first['role'] != 'user') {
      merged.insert(0, {'role': 'user', 'content': '(begin)'});
    }
    return merged;
  }

  Future<void> _streamAnthropic(
    ProviderCfg cfg,
    String model,
    String system,
    List<Map<String, dynamic>> wire,
    double temperature,
    int maxTokens,
    ThinkingLevel thinking,
    bool webSearch,
    List<Map<String, Object>> toolDefs,
    void Function(TurnEvent) onEvent,
  ) async {
    final thinkingOn = thinking != ThinkingLevel.off;
    final budget = thinking.anthropicBudget;
    final effectiveMax = math.max(maxTokens, budget + 2048);

    final tools = <Map<String, dynamic>>[
      ...toolDefs.map((t) => {
            'name': t['name'],
            'description': t['description'],
            'input_schema': t['parameters'],
          }),
      if (webSearch)
        const {
          'type': 'web_search_20250305',
          'name': 'web_search',
          'max_uses': 3,
        },
    ];

    final body = <String, dynamic>{
      'model': model,
      'system': system,
      'max_tokens': effectiveMax,
      'stream': true,
      'tools': tools,
      if (thinkingOn) ...{
        'thinking': {'type': 'enabled', 'budget_tokens': budget},
        'temperature': 1.0,
      } else
        'temperature': clampTemp(temperature),
    };

    final req = http.Request('POST', Uri.parse('${_trim(cfg.baseUrl)}/messages'))
      ..headers.addAll({
        'x-api-key': cfg.apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      })
      ..body = jsonEncode(body);

    final res = await _http.send(req);
    if (res.statusCode != 200) {
      throw LlmException(await _errorText(res, 'Anthropic'));
    }

    final blocks = <int, Map<String, dynamic>>{};
    var stopReason = '';
    var inTok = 0;
    var outTok = 0;

    await for (final raw in res.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final line = raw.trim();
      if (!line.startsWith('data:')) continue;
      Map<String, dynamic> j;
      try {
        j = jsonDecode(line.substring(5).trim()) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      switch (j['type']) {
        case 'message_start':
          final u = (j['message'] as Map?)?['usage'] as Map?;
          inTok = (u?['input_tokens'] as num?)?.toInt() ?? 0;
        case 'content_block_start':
          final idx = (j['index'] as num).toInt();
          final cb = j['content_block'] as Map? ?? {};
          blocks[idx] = {
            'type': cb['type'],
            'name': cb['name'],
            'id': cb['id'],
            'json': StringBuffer(),
          };
        case 'content_block_delta':
          final idx = (j['index'] as num).toInt();
          final b = blocks[idx];
          if (b == null) break;
          final d = j['delta'] as Map? ?? {};
          if (d['type'] == 'text_delta') {
            onEvent(DeltaText(d['text'] as String? ?? ''));
          } else if (d['type'] == 'thinking_delta') {
            onEvent(DeltaThinking(d['thinking'] as String? ?? ''));
          } else if (d['type'] == 'input_json_delta') {
            (b['json'] as StringBuffer).write(d['partial_json'] ?? '');
          }
        case 'message_delta':
          stopReason = (j['delta'] as Map?)?['stop_reason'] as String? ?? '';
          final u = j['usage'] as Map?;
          outTok = (u?['output_tokens'] as num?)?.toInt() ?? outTok;
      }
    }

    if (inTok > 0 || outTok > 0) {
      onEvent(UsageReported(MsgUsage(
        inputTokens: inTok,
        outputTokens: outTok,
        totalTokens: inTok + outTok,
      )));
    }

    if (stopReason == 'tool_use') {
      for (final b in blocks.values) {
        if (b['type'] == 'tool_use') {
          onEvent(ToolRequested(ToolCall(
            id: b['id'] as String? ?? '',
            name: b['name'] as String? ?? '',
            argsJson: (b['json'] as StringBuffer).toString(),
          )));
        }
      }
    }
  }

  // ------------------------------------------------------------------

  double clampTemp(double t) => math.max(0.0, math.min(1.0, t));

  String _trim(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  Future<List<int>> _post(
    String url, {
    required Map<String, String> headers,
    required String body,
  }) async {
    final res = await _http.post(Uri.parse(url), headers: headers, body: body);
    if (res.statusCode != 200) {
      String msg;
      try {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        msg = (j['error'] as Map?)?['message'] as String? ??
            j['error'] as String? ??
            res.body;
      } catch (_) {
        msg = res.body;
      }
      throw LlmException('HTTP ${res.statusCode} · ${_clip(msg, 300)}');
    }
    return res.bodyBytes;
  }

  Future<String> _errorText(http.StreamedResponse res, String label) async {
    final body = await res.stream.bytesToString();
    String msg = body;
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      msg = (j['error'] as Map?)?['message'] as String? ??
          j['message'] as String? ??
          j['error'] as String? ??
          body;
    } catch (_) {}
    return '$label HTTP ${res.statusCode} · ${_clip(msg, 300)}';
  }

  String _clip(String s, int n) =>
      s.length <= n ? s : '${s.substring(0, n)}…';
}
