import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../core/presets.dart';

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

final class ToolRequested extends TurnEvent {
  final ToolCall call;
  ToolRequested(this.call);
}

final class ToolFinished extends TurnEvent {
  final String name;
  final bool ok;
  final String output;
  ToolFinished(this.name, this.ok, this.output);
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

class LlmClient {
  final http.Client _http = http.Client();

  void dispose() => _http.close();

  // ------------------------------------------------------------------
  // Streaming turn
  // ------------------------------------------------------------------

  /// Streams one assistant turn from the wire history.
  /// [wire] is neutral-format history; converted per-protocol internally.
  Future<void> streamTurn({
    required ProviderCfg cfg,
    required String model,
    required String system,
    required List<Map<String, dynamic>> wire,
    double temperature = 0.7,
    int maxTokens = 2048,
    required void Function(TurnEvent) onEvent,
  }) async {
    switch (cfg.protocol) {
      case Protocol.openai:
        await _streamOpenAI(cfg, model, system, wire, temperature, maxTokens, onEvent);
      case Protocol.anthropic:
        await _streamAnthropic(cfg, model, system, wire, temperature, maxTokens, onEvent);
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
      final body = _anthropicBody(
          cfg, model, system, wire, 0.3, maxTokens, false, null);
      final res = await _post(
        '${_trim(cfg.baseUrl)}/messages',
        headers: {
          'x-api-key': cfg.apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: body,
      );
      final data = jsonDecode(utf8.decode(res));
      for (final block in (data['content'] as List? ?? [])) {
        if (block is Map && block['type'] == 'text') {
          buf.write(block['text'] ?? '');
        }
      }
      return buf.toString();
    }

    final msgs = _openAIMessages(system, wire);
    final res = await _post(
      '${_trim(cfg.baseUrl)}/chat/completions',
      headers: _openAIHeaders(cfg),
      body: jsonEncode({
        'model': model,
        'messages': msgs,
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
            out.add({'role': 'tool', 'tool_call_id': xm['id'], 'content': xm['out']});
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
    void Function(TurnEvent) onEvent,
  ) async {
    final url =
        '${_trim(cfg.baseUrl)}/chat/completions';
    final req = http.Request('POST', Uri.parse(url))
      ..headers.addAll(_openAIHeaders(cfg))
      ..body = jsonEncode({
        'model': model,
        'messages': _openAIMessages(system, wire),
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream': true,
        'tools': _memoryToolDefs.map((t) => {
              'type': 'function',
              'function': t,
            }).toList(),
      });

    final res = await _http.send(req);
    if (res.statusCode != 200) {
      throw LlmException(await _errorText(res, 'OpenAI'));
    }

    final calls = <int, ToolCall>{};
    final argsBuf = <int, StringBuffer>{};
    var sawToolCall = false;

    await for (final line in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
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
      final choices = j['choices'] as List?;
      if (choices == null || choices.isEmpty) continue;
      final delta = (choices.first as Map)['delta'] as Map? ?? {};
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
            sawToolCall = true;
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
    if (!sawToolCall && calls.isEmpty) return;
  }

  // ------------------------------------------------------------------
  // Anthropic-native
  // ------------------------------------------------------------------

  String _anthropicBody(
    ProviderCfg cfg,
    String model,
    String system,
    List<Map<String, dynamic>> wire,
    double temperature,
    int maxTokens,
    bool stream,
    List<Map<String, Object>>? tools,
  ) {
    return jsonEncode({
      'model': model,
      'system': system,
      'max_tokens': maxTokens,
      'temperature': clampTemp(temperature),
      if (stream) 'stream': true,
      if (tools != null)
        'tools': tools
            .map((t) => {
                  'name': t['name'],
                  'description': t['description'],
                  'input_schema': t['parameters'],
                })
            .toList(),
      'messages': _anthropicMessages(wire),
    });
  }

  List<Map<String, dynamic>> _anthropicMessages(List<Map<String, dynamic>> wire) {
    // Convert then merge consecutive same-role messages.
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
                input = tm['args'].toString().isEmpty
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
    // merge consecutive same-role
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
    if (merged.isEmpty ||
        merged.first['role'] != 'user') {
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
    void Function(TurnEvent) onEvent,
  ) async {
    final url = '${_trim(cfg.baseUrl)}/messages';
    final tools = _memoryToolDefs
        .map<Map<String, Object>>(
            (t) => Map<String, Object>.from(t as Map))
        .toList();
    final req = http.Request('POST', Uri.parse(url))
      ..headers.addAll({
        'x-api-key': cfg.apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      })
      ..body = _anthropicBody(cfg, model, system, wire, temperature, maxTokens, true, tools);

    final res = await _http.send(req);
    if (res.statusCode != 200) {
      throw LlmException(await _errorText(res, 'Anthropic'));
    }

    // index -> {type,name,id,textBuf,jsonBuf}
    final blocks = <int, Map<String, dynamic>>{};
    var stopReason = '';

    await for (final raw in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      final line = raw.trim();
      if (!line.startsWith('data:')) continue;
      Map<String, dynamic> j;
      try {
        j = jsonDecode(line.substring(5).trim()) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      switch (j['type']) {
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
          } else if (d['type'] == 'input_json_delta') {
            (b['json'] as StringBuffer).write(d['partial_json'] ?? '');
          }
        case 'message_delta':
          stopReason = (j['delta'] as Map?)?['stop_reason'] as String? ?? '';
      }
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
