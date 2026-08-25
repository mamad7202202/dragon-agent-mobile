import 'dart:convert';

/// Neutral wire entry kinds stored inside a session transcript.
///
/// r: 'u' user text · 'a' assistant text (+'k' thinking) · 'at' tool-call batch
/// 'tr' tool results · 's' compaction summary
class Wire {
  static Map<String, dynamic> user(String text) => {'r': 'u', 'c': text};

  static Map<String, dynamic> assistant(String text, {String? thinking}) => {
        'r': 'a',
        'c': text,
        if (thinking != null && thinking.isNotEmpty) 'k': thinking,
      };

  static Map<String, dynamic> summary(String text) =>
      {'r': 's', 'c': text, 'n': 0};

  static Map<String, dynamic> assistantToolCalls(
          List<Map<String, String>> calls) =>
      {'r': 'at', 't': calls}; // {id,name,args}

  static Map<String, dynamic> toolResults(List<Map<String, String>> outs) =>
      {'r': 'tr', 'x': outs}; // {id,name,out}
}

/// Token usage reported by the provider for one assistant turn.
class MsgUsage {
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;

  const MsgUsage({
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
  });

  String get short {
    final total = totalTokens > 0
        ? totalTokens
        : inputTokens + outputTokens;
    if (total >= 1000) {
      return '${(total / 1000).toStringAsFixed(1)}k tokens';
    }
    return '$total tokens';
  }
}

enum ToolStatus { running, ok, denied, error }

/// A single display item derived from the wire.
enum BubbleKind { user, assistant, error, toolUse, summary }

class Bubble {
  final String id;
  final BubbleKind kind;
  final String? text;
  final String? thinking;
  final MsgUsage? usage;
  final String? toolName;
  final String? toolArgs;
  final ToolStatus? toolStatus;
  final String? toolOutput;
  final bool streaming;

  const Bubble({
    required this.id,
    required this.kind,
    this.text,
    this.thinking,
    this.usage,
    this.toolName,
    this.toolArgs,
    this.toolStatus,
    this.toolOutput,
    this.streaming = false,
  });

  Bubble copyWith({
    String? text,
    String? thinking,
    bool? streaming,
    MsgUsage? usage,
  }) =>
      Bubble(
        id: id,
        kind: kind,
        text: text ?? this.text,
        thinking: thinking ?? this.thinking,
        usage: usage ?? this.usage,
        toolName: toolName,
        toolArgs: toolArgs,
        toolStatus: toolStatus,
        toolOutput: toolOutput,
        streaming: streaming ?? this.streaming,
      );
}

/// Derive display bubbles from a neutral wire list.
List<Bubble> deriveBubbles(List<Map<String, dynamic>> wire) {
  // collect tool results by call id for status/output attachment
  final resultsById = <String, Map<String, dynamic>>{};
  for (final m in wire) {
    if (m['r'] == 'tr') {
      for (final x in (m['x'] as List).cast<Map<String, dynamic>>()) {
        resultsById[x['id']?.toString() ?? ''] = x;
      }
    }
  }

  ToolStatus statusFor(String? out) {
    if (out == null) return ToolStatus.running;
    if (out.contains('"denied"')) return ToolStatus.denied;
    if (out.contains('"error"')) return ToolStatus.error;
    return ToolStatus.ok;
  }

  final out = <Bubble>[];
  var i = 0;
  for (final m in wire) {
    final idx = i++;
    switch (m['r'] as String) {
      case 'u':
        out.add(Bubble(
            id: 'b$idx', kind: BubbleKind.user, text: m['c'] as String));
      case 'a':
        out.add(Bubble(
          id: 'b$idx',
          kind: BubbleKind.assistant,
          text: m['c'] as String,
          thinking: m['k'] as String?,
        ));
      case 'at':
        for (final t in (m['t'] as List).cast<Map<String, dynamic>>()) {
          final callId = t['id']?.toString() ?? '';
          final result = resultsById[callId];
          final resultOut = result?['out']?.toString();
          out.add(Bubble(
            id: 'b$idx-$callId',
            kind: BubbleKind.toolUse,
            toolName: t['name'] as String?,
            toolArgs: t['args'] as String?,
            toolStatus: statusFor(resultOut),
            toolOutput: resultOut,
          ));
        }
      case 's':
        out.add(Bubble(
            id: 'b$idx',
            kind: BubbleKind.summary,
            text:
                '${(m['n'] as num?)?.toInt() ?? 0} older turns folded into memory'));
    }
  }
  return out;
}

String sessionTitleFromWire(List<Map<String, dynamic>> wire) {
  for (final m in wire) {
    if (m['r'] == 'u') {
      final t = (m['c'] as String).trim().replaceAll('\n', ' ');
      if (t.isNotEmpty) {
        return t.length > 48 ? '${t.substring(0, 48)}…' : t;
      }
    }
  }
  return 'New session';
}

String prettyJson(Object? o) {
  try {
    return const JsonEncoder.withIndent('  ').convert(o);
  } catch (_) {
    return o.toString();
  }
}
