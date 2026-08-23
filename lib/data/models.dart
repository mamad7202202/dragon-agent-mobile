import 'dart:convert';

/// Neutral wire entry kinds stored inside a session transcript.
///
/// r: 'u' user text · 'a' assistant text · 'at' assistant tool-call batch
/// 'tr' tool results · 's' compaction summary
class Wire {
  static Map<String, dynamic> user(String text) => {'r': 'u', 'c': text};
  static Map<String, dynamic> assistant(String text) => {'r': 'a', 'c': text};
  static Map<String, dynamic> summary(String text) =>
      {'r': 's', 'c': text, 'n': 0};

  static Map<String, dynamic> assistantToolCalls(
          List<Map<String, String>> calls) =>
      {'r': 'at', 't': calls}; // {id,name,args}

  static Map<String, dynamic> toolResults(List<Map<String, String>> outs) =>
      {'r': 'tr', 'x': outs}; // {id,name,out}
}

/// A single display item derived from the wire.
enum BubbleKind { user, assistant, error, toolUse, summary }

class Bubble {
  final String id;
  final BubbleKind kind;
  final String? text;
  final String? toolName;
  final String? toolArgs;
  final bool streaming;

  const Bubble({
    required this.id,
    required this.kind,
    this.text,
    this.toolName,
    this.toolArgs,
    this.streaming = false,
  });

  Bubble copyWith({String? text, bool? streaming}) => Bubble(
        id: id,
        kind: kind,
        text: text ?? this.text,
        toolName: toolName,
        toolArgs: toolArgs,
        streaming: streaming ?? this.streaming,
      );
}

/// Derive display bubbles from a neutral wire list.
List<Bubble> deriveBubbles(List<Map<String, dynamic>> wire,
    {String? liveText, int liveIndex = -1}) {
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
            streaming: idx == liveIndex && liveText != null));
      case 'at':
        for (final t in (m['t'] as List).cast<Map<String, dynamic>>()) {
          out.add(Bubble(
            id: 'b$idx-${t['id']}',
            kind: BubbleKind.toolUse,
            toolName: t['name'] as String?,
            toolArgs: t['args'] as String?,
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
  if (liveText != null && liveIndex >= wire.length) {
    out.add(Bubble(
        id: 'live',
        kind: out.isEmpty ? BubbleKind.user : BubbleKind.assistant,
        text: liveText,
        streaming: true));
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

Map<String, dynamic> factToJson(Map<String, dynamic> f) => f;

String prettyJson(Object? o) {
  try {
    return const JsonEncoder.withIndent('  ').convert(o);
  } catch (_) {
    return o.toString();
  }
}
