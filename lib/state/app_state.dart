import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/graph_memory.dart';
import '../data/llm.dart';
import '../data/memory.dart';
import '../data/models.dart';
import '../data/sessions.dart';
import '../services/update_service.dart';

enum MemoryMode { hybrid, outline }

enum ApprovalDecision { once, session, deny }

/// Safe arithmetic evaluator — tokenizer + recursive descent, no eval().
double? evaluateExpression(String input) {
  final src = input.replaceAll('×', '*').replaceAll('÷', '/').trim();
  if (src.isEmpty || src.length > 200) return null;
  final tokens = <String>[];
  var i = 0;
  while (i < src.length) {
    final c = src[i];
    if (c == ' ') {
      i++;
      continue;
    }
    if ('+-*/%^()'.contains(c)) {
      tokens.add(c);
      i++;
    } else if ('0123456789.'.contains(c)) {
      var j = i;
      while (j < src.length && '0123456789.'.contains(src[j])) {
        j++;
      }
      tokens.add(src.substring(i, j));
      i = j;
    } else {
      return null;
    }
  }
  final parser = _ExprParser(tokens);
  return parser.parseFull();
}

class _ExprParser {
  final List<String> tokens;
  var pos = 0;
  _ExprParser(this.tokens);

  String? peek() => pos < tokens.length ? tokens[pos] : null;
  String eat() => tokens[pos++];

  double? parseFull() {
    final result = parseExpr();
    if (result == null || pos != tokens.length) return null;
    return result;
  }

  double? parseExpr() {
    var left = parseTerm();
    if (left == null) return null;
    while (peek() == '+' || peek() == '-') {
      final op = eat();
      final right = parseTerm();
      if (right == null) return null;
      left = (op == '+') ? left! + right : left! - right;
    }
    return left;
  }

  double? parseTerm() {
    var left = parsePower();
    if (left == null) return null;
    while (peek() == '*' || peek() == '/' || peek() == '%') {
      final op = eat();
      final right = parsePower();
      if (right == null) return null;
      if (op == '*') {
        left = left! * right;
      } else if (op == '/') {
        if (right == 0) return null;
        left = left! / right;
      } else {
        if (right == 0) return null;
        left = left! % right;
      }
    }
    return left;
  }

  double? parsePower() {
    final base = parseUnary();
    if (base == null) return null;
    if (peek() == '^') {
      eat();
      final exp = parsePower();
      if (exp == null) return null;
      return math.pow(base, exp).toDouble();
    }
    return base;
  }

  double? parseUnary() {
    if (peek() == '-') {
      eat();
      final v = parseUnary();
      return v == null ? null : -v;
    }
    if (peek() == '+') {
      eat();
      return parseUnary();
    }
    return parseAtom();
  }

  double? parseAtom() {
    final t = peek();
    if (t == null) return null;
    if (t == '(') {
      eat();
      final v = parseExpr();
      if (v == null || peek() != ')') return null;
      eat();
      return v;
    }
    return double.tryParse(eat());
  }
}

class ApprovalRequest {
  final String callId;
  final String tool;
  final String argsJson;
  final Completer<ApprovalDecision> completer;

  ApprovalRequest({
    required this.callId,
    required this.tool,
    required this.argsJson,
    required this.completer,
  });
}

class Settings {
  double temperature;
  int maxTokens;
  int compactionAfter;
  bool memoryEnabled;
  int themeMode; // ThemeMode index: 0 system, 1 light, 2 dark
  int thinking; // ThinkingLevel index
  bool webSearch;
  int memoryMode; // MemoryMode index: 0 hybrid, 1 outline

  Settings({
    this.temperature = 0.7,
    this.maxTokens = 2048,
    this.compactionAfter = 36,
    this.memoryEnabled = true,
    this.themeMode = 2,
    this.thinking = 0,
    this.webSearch = false,
    this.memoryMode = 0,
  });

  ThemeMode get theme => ThemeMode.values[themeMode.clamp(0, 2)];
  ThinkingLevel get thinkingLevel =>
      ThinkingLevel.values[thinking.clamp(0, 3)];
  MemoryMode get mode => MemoryMode.values[memoryMode.clamp(0, 1)];

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'max_tokens': maxTokens,
        'compaction_after': compactionAfter,
        'memory_enabled': memoryEnabled,
        'theme_mode': themeMode,
        'thinking': thinking,
        'web_search': webSearch,
        'memory_mode': memoryMode,
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        temperature: (j['temperature'] as num?)?.toDouble() ?? 0.7,
        maxTokens: (j['max_tokens'] as num?)?.toInt() ?? 2048,
        compactionAfter: (j['compaction_after'] as num?)?.toInt() ?? 36,
        memoryEnabled: j['memory_enabled'] as bool? ?? true,
        themeMode: (j['theme_mode'] as num?)?.toInt() ?? 2,
        thinking: (j['thinking'] as num?)?.toInt() ?? 0,
        webSearch: j['web_search'] as bool? ?? false,
        memoryMode: (j['memory_mode'] as num?)?.toInt() ?? 0,
      );
}

/// Tools that touch user data destructively — gated by an approval card.
const sensitiveTools = {'forget_memory', 'memory_delete', 'remember_rule'};

/// Central app controller.
class AppState extends ChangeNotifier {
  final LlmClient _llm = LlmClient();
  final MemoryStore memory = MemoryStore();
  final GraphMemoryStore graph = GraphMemoryStore();
  final SessionStore sessions = SessionStore();

  late SharedPreferences _prefs;

  // config
  Map<String, ProviderCfg> providers = {};
  String activeProvider = '';
  String activeModel = '';
  Settings settings = Settings();

  // session
  SessionData? current;
  List<Bubble> bubbles = [];

  // streaming state
  bool busy = false;
  String? liveText;
  String? liveThinking;

  // approvals
  ApprovalRequest? pendingApproval;
  final Set<String> _sessionAllowed = {};

  // navigation intents consumed by UI
  int memoriesOpenTick = 0;

  // ---- update state ----
  final UpdateService _updates = UpdateService();
  StreamSubscription? _connectivitySub;
  DateTime _lastUpdateCheck = DateTime.fromMillisecondsSinceEpoch(0);

  UpdateInfo? pendingUpdate;
  UpdatePhase updatePhase = UpdatePhase.idle;
  double downloadProgress = 0;
  String? downloadedApkPath;
  String? updateError;
  String? lastUpdateNotice;
  bool updateDismissed = false;
  String appVersion = '…';

  bool get configured =>
      providers.isNotEmpty &&
      providers[activeProvider] != null &&
      activeModel.isNotEmpty;

  ProviderCfg? get cfg => providers[activeProvider];

  /// True once init() finished loading persisted state.
  bool ready = false;

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {
      ready = true;
      notifyListeners();
      return;
    }
    try {
      await _loadEverything();
    } catch (_) {
      // never leave the app stuck on the splash screen
    } finally {
      ready = true;
      notifyListeners();
    }
    unawaited(_startUpdateWatch());
  }

  Future<void> _loadEverything() async {
    try {
      await memory.load();
    } catch (_) {}
    try {
      await graph.load();
    } catch (_) {}
    try {
      await sessions.loadIndex();
    } catch (_) {}

    final rawProviders = _prefs.getString('providers');
    if (rawProviders != null) {
      final map = jsonDecode(rawProviders) as Map<String, dynamic>;
      providers = map.map(
        (k, v) => MapEntry(k, ProviderCfg.fromJson(Map<String, dynamic>.from(v as Map))),
      );
    }
    activeProvider = _prefs.getString('active_provider') ?? '';
    activeModel = _prefs.getString('active_model') ?? '';
    if (!providers.containsKey(activeProvider) && providers.isNotEmpty) {
      activeProvider = providers.keys.first;
      if (activeModel.isEmpty && providers[activeProvider]!.models.isNotEmpty) {
        activeModel = providers[activeProvider]!.models.first;
      }
    }
    final rawSettings = _prefs.getString('settings');
    if (rawSettings != null) {
      try {
        settings = Settings.fromJson(
            Map<String, dynamic>.from(jsonDecode(rawSettings) as Map));
      } catch (_) {}
    }

    try {
      appVersion = await _updates.currentVersion();
    } catch (_) {}

    // resume latest session
    if (configured && sessions.metas.isNotEmpty) {
      try {
        current = await sessions.open(sessions.metas.first.id);
        _rebuildBubbles();
      } catch (_) {}
    }
  }

  Future<void> _persistConfig() async {
    await _prefs.setString(
      'providers',
      jsonEncode(providers.map((k, v) => MapEntry(k, v.toJson()))),
    );
    await _prefs.setString('active_provider', activeProvider);
    await _prefs.setString('active_model', activeModel);
    await _prefs.setString('settings', jsonEncode(settings.toJson()));
  }

  // ------------------------------------------------------------------
  // provider / model management
  // ------------------------------------------------------------------

  Future<void> saveProvider(ProviderCfg p, {bool activate = true}) async {
    providers[p.name] = p;
    if (activate || !configured) {
      activeProvider = p.name;
      if (p.models.isNotEmpty && !p.models.contains(activeModel)) {
        activeModel = p.models.first;
      }
    }
    await _persistConfig();
    notifyListeners();
  }

  Future<void> removeProvider(String name) async {
    providers.remove(name);
    if (activeProvider == name) {
      activeProvider = providers.keys.firstOrNull ?? '';
      activeModel = '';
    }
    await _persistConfig();
    notifyListeners();
  }

  Future<void> setActiveModel(String model) async {
    activeModel = model;
    final c = cfg;
    if (c != null && !c.models.contains(model)) {
      c.models = [model, ...c.models];
    }
    await _persistConfig();
    notifyListeners();
  }

  Future<void> updateSettings(Settings s) async {
    settings = s;
    await _persistConfig();
    notifyListeners();
  }

  Future<void> resetEverything() async {
    await _prefs.clear();
    memory.clear();
    graph.sections.clear();
    try {
      await memory.saveFacts();
      await graph.save();
    } catch (_) {}
    for (final m in List<SessionMeta>.from(sessions.metas)) {
      await sessions.delete(m.id);
    }
    providers.clear();
    activeProvider = '';
    activeModel = '';
    current = null;
    bubbles = [];
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // approvals
  // ------------------------------------------------------------------

  Future<ApprovalDecision> _gateTool(String tool, String argsJson,
      {required String callId}) async {
    if (!sensitiveTools.contains(tool)) return ApprovalDecision.once;
    if (_sessionAllowed.contains(tool)) return ApprovalDecision.session;

    final completer = Completer<ApprovalDecision>();
    pendingApproval = ApprovalRequest(
      callId: callId,
      tool: tool,
      argsJson: argsJson,
      completer: completer,
    );
    notifyListeners();
    final decision = await completer.future;
    pendingApproval = null;
    notifyListeners();
    return decision;
  }

  void resolveApproval(ApprovalDecision decision) {
    final req = pendingApproval;
    if (req == null) return;
    if (decision == ApprovalDecision.session) {
      _sessionAllowed.add(req.tool);
    }
    req.completer.complete(decision);
  }

  // ------------------------------------------------------------------
  // chat
  // ------------------------------------------------------------------

  Future<void> newSession() async {
    if (busy) return;
    current = await sessions.create();
    bubbles = [];
    liveText = null;
    liveThinking = null;
    notifyListeners();
  }

  Future<void> openSession(String id) async {
    if (busy) return;
    try {
      current = await sessions.open(id);
      bubbles = deriveBubbles(current!.wire);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> deleteSession(String id) async {
    await sessions.delete(id);
    if (current?.id == id) {
      current = null;
      bubbles = [];
    }
    notifyListeners();
  }

  void openMemories() {
    memoriesOpenTick++;
    notifyListeners();
  }

  void appendLocalBubble(Bubble b) {
    bubbles = [...bubbles, b];
    notifyListeners();
  }

  /// Handles slash commands; returns true if handled.
  bool handleCommand(String input) {
    final cmd = input.trim().split(RegExp(r'\s+')).first.toLowerCase();
    switch (cmd) {
      case '/new':
        newSession();
        return true;
      case '/memories':
        openMemories();
        return true;
      case '/help':
        appendLocalBubble(const Bubble(
          id: 'help',
          kind: BubbleKind.assistant,
          text: '**Commands**\n\n'
              '- `/new` — start a fresh session\n'
              '- `/remember <fact>` — pin a long-term fact\n'
              '- `/forget <id>` — delete a fact by id\n'
              '- `/memories` — open the memory manager\n'
              '- `/clear` — wipe every saved fact\n'
              '- `/help` — this message\n',
        ));
        return true;
      case '/remember':
        final fact = input.trim().substring('/remember'.length).trim();
        if (fact.isEmpty) return false;
        if (settings.mode == MemoryMode.outline) {
          final ids = graph.write('facts', [fact]);
          appendLocalBubble(Bubble(
            id: 'cmd-${ids.first}',
            kind: BubbleKind.toolUse,
            toolName: 'memory_write',
            toolArgs: '{"section": "facts", "bullets": ["$fact"]}',
            toolStatus: ToolStatus.ok,
          ));
        } else {
          final f = memory.add(fact);
          appendLocalBubble(Bubble(
            id: 'cmd-${f.id}',
            kind: BubbleKind.toolUse,
            toolName: 'save_memory',
            toolArgs: '{"text": "$fact"}',
            toolStatus: ToolStatus.ok,
          ));
        }
        return true;
      case '/forget':
        final id = input.trim().substring('/forget'.length).trim();
        final ok = settings.mode == MemoryMode.outline
            ? graph.remove(id: id)
            : memory.remove(id);
        appendLocalBubble(Bubble(
          id: 'cmd-forget-$id',
          kind: ok ? BubbleKind.assistant : BubbleKind.error,
          text: ok ? 'Fact `$id` forgotten.' : 'No fact matching `$id`.',
        ));
        return true;
      case '/clear':
        memory.clear();
        graph.sections.clear();
        appendLocalBubble(const Bubble(
          id: 'cmd-clear',
          kind: BubbleKind.assistant,
          text:
              'All facts cleared. MEMORY.md is kept — edit it in **Memories → Rules**.',
        ));
        return true;
    }
    return false;
  }

  Future<void> send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || busy || !configured) return;
    if (text.startsWith('/') && handleCommand(text)) return;

    current ??= await sessions.create();

    current!.wire.add(Wire.user(text));
    bubbles = [
      ...bubbles,
      Bubble(id: 'u${current!.wire.length}', kind: BubbleKind.user, text: text),
    ];
    unawaited(sessions.persist(current!));
    notifyListeners();

    await runTurn();
  }

  /// Agent loop: stream a turn, gate + execute tools, repeat up to N rounds.
  Future<void> runTurn() async {
    final session = current!;
    busy = true;
    liveText = null;
    liveThinking = null;
    var lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

    void throttledNotify() {
      final now = DateTime.now();
      if (now.difference(lastNotify).inMilliseconds >= 60) {
        lastNotify = now;
        notifyListeners();
      }
    }

    try {
      for (var round = 0; round < 5; round++) {
        final assistantBuf = StringBuffer();
        final thinkingBuf = StringBuffer();
        final calls = <ToolCall>[];
        MsgUsage? usage;

        await _llm.streamTurn(
          cfg: cfg!,
          model: activeModel,
          system: _buildSystem(session),
          wire: session.wire,
          temperature: settings.temperature,
          maxTokens: settings.maxTokens,
          thinking: settings.thinkingLevel,
          webSearch: settings.webSearch && cfg!.supportsWebSearch,
          toolDefs: _activeToolDefs(),
          onEvent: (e) {
            switch (e) {
              case DeltaText():
                assistantBuf.write(e.text);
                liveText = assistantBuf.toString();
                throttledNotify();
              case DeltaThinking():
                thinkingBuf.write(e.text);
                liveThinking = thinkingBuf.toString();
                throttledNotify();
              case UsageReported():
                usage = e.usage;
              case ToolRequested():
                calls.add(e.call);
            }
          },
        );

        final text = assistantBuf.toString().trim();
        final thinking = thinkingBuf.toString().trim();

        if (calls.isEmpty) {
          session.wire.add(Wire.assistant(text, thinking: thinking));
          bubbles = [
            ...bubbles,
            Bubble(
              id: 'a${session.wire.length}',
              kind: BubbleKind.assistant,
              text: text.isEmpty ? '_(empty response)_' : text,
              thinking: thinking.isEmpty ? null : thinking,
              usage: usage,
            ),
          ];
          break;
        }

        if (text.isNotEmpty || thinking.isNotEmpty) {
          session.wire.add(Wire.assistant(text, thinking: thinking));
          bubbles = [
            ...bubbles,
            Bubble(
              id: 'at${session.wire.length}',
              kind: BubbleKind.assistant,
              text: text,
              thinking: thinking.isEmpty ? null : thinking,
              usage: usage,
            ),
          ];
        }

        // live "running" chips so the user sees activity during gate + exec
        for (final call in calls) {
          bubbles = [
            ...bubbles,
            Bubble(
              id: 'live-tool-${call.id}',
              kind: BubbleKind.toolUse,
              toolName: call.name,
              toolArgs: call.argsJson,
              toolStatus: ToolStatus.running,
            ),
          ];
        }
        notifyListeners();

        final executed = <Map<String, String>>[];
        for (final call in calls) {
          final decision = await _gateTool(call.name, call.argsJson,
              callId: call.id);
          String out;
          if (decision == ApprovalDecision.deny) {
            out = jsonEncode({
              'ok': false,
              'denied': true,
              'reason': 'the user denied this action',
            });
          } else {
            if (decision == ApprovalDecision.session) {
              _sessionAllowed.add(call.name);
            }
            out = _execTool(call);
          }
          executed.add({'id': call.id, 'name': call.name, 'out': out});
        }

        session.wire.add(Wire.assistantToolCalls(
          calls
              .map((c) => {'id': c.id, 'name': c.name, 'args': c.argsJson})
              .toList(),
        ));
        session.wire.add(Wire.toolResults(executed));
        await _saveMemoryStores();
        bubbles = deriveBubbles(session.wire);
        notifyListeners();
      }

      unawaited(sessions.persist(session));
      await maybeCompact();
    } on LlmException catch (e) {
      bubbles = [
        ...bubbles,
        Bubble(
          id: 'err${DateTime.now().millisecondsSinceEpoch}',
          kind: BubbleKind.error,
          text: e.message,
        ),
      ];
    } catch (e) {
      bubbles = [
        ...bubbles,
        Bubble(
          id: 'err${DateTime.now().millisecondsSinceEpoch}',
          kind: BubbleKind.error,
          text: e.toString(),
        ),
      ];
    } finally {
      busy = false;
      liveText = null;
      liveThinking = null;
      notifyListeners();
    }
  }

  List<Map<String, Object>> _activeToolDefs() {
    final defs = List<Map<String, Object>>.from(extraToolDefs);
    if (!settings.memoryEnabled) return defs;
    if (settings.mode == MemoryMode.outline) {
      defs.addAll(outlineToolDefs);
    } else {
      defs.addAll(memoryToolDefs);
    }
    return defs;
  }

  Future<void> _saveMemoryStores() async {
    try {
      if (settings.mode == MemoryMode.outline) {
        await graph.save();
      } else {
        await memory.saveFacts();
      }
    } catch (_) {}
  }

  String _execTool(ToolCall call) {
    try {
      final args = call.argsJson.trim().isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(call.argsJson) as Map);
      switch (call.name) {
        case 'save_memory':
          final fact = memory.add(
            args['text'] as String? ?? '',
            importance: ((args['importance'] as num?)?.toDouble()) ?? 0.5,
          );
          return jsonEncode({'ok': true, 'id': fact.id});
        case 'forget_memory':
          final ok = memory.remove(args['id'] as String? ?? '');
          return jsonEncode({'ok': ok});
        case 'memory_write':
          final section = args['section'] as String? ?? 'facts';
          final bullets =
              (args['bullets'] as List?)?.cast<String>() ?? const [];
          final ids = graph.write(section, bullets);
          return jsonEncode({'ok': true, 'section': section, 'ids': ids});
        case 'memory_delete':
          final ok = graph.remove(
            id: args['id'] as String?,
            section: args['section'] as String?,
          );
          return jsonEncode({'ok': ok});
        case 'memory_read':
          return jsonEncode({
            'ok': true,
            'outline': graph.outline(maxChars: 3000),
            'full': graph.listAll(),
          });
        case 'list_memories':
          if (settings.mode == MemoryMode.outline) {
            return jsonEncode({'ok': true, 'memory': graph.listAll()});
          }
          final buf = StringBuffer();
          for (final f in memory.all) {
            buf.writeln('- (${f.id}) ${f.content}');
          }
          return jsonEncode({
            'ok': true,
            'memory': buf.toString().trim().isEmpty
                ? '(memory is empty)'
                : buf.toString().trim(),
          });
        case 'remember_rule':
          final rule = (args['rule'] as String? ?? '').trim();
          if (rule.isEmpty) {
            return jsonEncode({'ok': false, 'error': 'empty rule'});
          }
          final current = memory.procedural;
          final updated =
              current.isEmpty ? '- $rule' : '$current\n- $rule';
          memory.saveProcedural(updated);
          return jsonEncode({'ok': true, 'rule': rule});
        case 'datetime':
          final now = DateTime.now();
          final offset = now.timeZoneOffset;
          final sign = offset.isNegative ? '-' : '+';
          return jsonEncode({
            'ok': true,
            'local': now.toIso8601String(),
            'weekday': [
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
              'Saturday',
              'Sunday'
            ][now.weekday - 1],
            'timezone': 'UTC$sign${offset.inHours}:${(offset.inMinutes.abs() % 60).toString().padLeft(2, '0')}',
          });
        case 'calculator':
          final expr = args['expression'] as String? ?? '';
          final value = _calc(expr);
          if (value == null) {
            return jsonEncode({'ok': false, 'error': 'cannot parse "$expr"'});
          }
          return jsonEncode({
            'ok': true,
            'expression': expr,
            'result': value == value.roundToDouble()
                ? value.round().toString()
                : value.toStringAsFixed(6),
          });
        case 'device_info':
          return jsonEncode({
            'ok': true,
            'os': Platform.operatingSystem,
            'osVersion': Platform.operatingSystemVersion,
            'locale': Platform.localeName,
            'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
            'app': 'Dragon Agent Mobile v$appVersion',
          });
        default:
          return jsonEncode({'error': 'unknown tool ${call.name}'});
      }
    } catch (e) {
      return jsonEncode({'error': e.toString()});
    }
  }

  // ---- tiny safe arithmetic evaluator (no eval) ----

  double? _calc(String input) => evaluateExpression(input);

  // ------------------------------------------------------------------
  // system prompt
  // ------------------------------------------------------------------

  String _buildSystem(SessionData session) {
    final buf = StringBuffer();
    buf.writeln(
        'You are Dragon Agent, a sharp, warm and concise AI assistant living '
        "inside the user's pocket. You have a persistent memory and a set of "
        'tools. Use tools whenever they help; prefer acting over asking.');

    if (settings.memoryEnabled) {
      if (settings.mode == MemoryMode.outline) {
        buf.writeln();
        buf.writeln('MEMORY SYSTEM — OUTLINE MODE');
        buf.writeln(
            'Long-term memory is a compact hierarchical outline of sections '
            'and one-line bullets (profile, preferences, projects, people, '
            'goals, facts — you may create new sections).');
        buf.writeln('- When you learn something durable, upsert it with '
            'memory_write. Bullets must stand alone, ≤140 chars.');
        buf.writeln('- Keep it tidy: delete stale entries with memory_delete '
            '(the user approves destructive actions).');
        buf.writeln('- The outline below IS your current memory — trust it, '
            'and keep it accurate. It costs very few tokens, so keep bullets '
            'dense.');
        final outline = graph.outline();
        if (outline.isNotEmpty) {
          buf.writeln();
          buf.writeln(outline);
        }
      } else {
        buf.writeln();
        buf.writeln('MEMORY TOOLS — you carry two tools:');
        buf.writeln('- save_memory(text, importance): store durable facts '
            'about the user, their projects or decisions. Use it whenever you '
            'notice something worth remembering across sessions (preferences, '
            'names, goals, corrections). Do not store trivial chatter.');
        buf.writeln('- forget_memory(id): remove an obsolete fact by id '
            'prefix.');
        final facts = memory.all;
        if (facts.isNotEmpty) {
          buf.writeln();
          buf.writeln('[KNOWN FACTS]');
          for (final f in facts) {
            buf.writeln('- (${f.id}) ${f.content}');
          }
        }
      }
      final procedural = memory.proceduralBlock();
      if (procedural != null) {
        buf.writeln();
        buf.writeln(procedural);
      }
    }

    buf.writeln();
    buf.writeln('OTHER TOOLS: datetime (current time), calculator (exact '
        'arithmetic), list_memories (inspect memory), device_info, and '
        'remember_rule (persistent user rules — sensitive).');

    if (session.wire.where((m) => m['r'] == 's').isNotEmpty) {
      buf.writeln();
      buf.writeln('(Earlier parts of this conversation were compacted into '
          'the summaries you see inline.)');
    }
    return buf.toString();
  }

  /// Fold old turns into one summary when history grows past the threshold.
  Future<void> maybeCompact() async {
    final session = current!;
    final conversational =
        session.wire.where((m) => m['r'] == 'u' || m['r'] == 'a').length;
    if (conversational <= settings.compactionAfter) return;
    if (busy) return;

    const keepRecent = 8;
    final idxUserAssistant = <int>[];
    for (var i = 0; i < session.wire.length; i++) {
      final r = session.wire[i]['r'];
      if (r == 'u' || r == 'a') idxUserAssistant.add(i);
    }
    if (idxUserAssistant.length <= keepRecent + 2) return;
    final cutWireIdx = idxUserAssistant[idxUserAssistant.length - keepRecent];

    final old = session.wire.sublist(0, cutWireIdx);
    final recent = session.wire.sublist(cutWireIdx);

    final transcript =
        StringBuffer('Transcript of an earlier conversation:\n\n');
    for (final m in old) {
      final r = m['r'] as String?;
      if (r == 'u') {
        transcript.writeln('User: ${_clip(m['c']?.toString() ?? '', 700)}');
      } else if (r == 'a') {
        transcript.writeln('Dragon: ${_clip(m['c']?.toString() ?? '', 700)}');
      } else if (r == 's') {
        transcript.writeln('[summary] ${m['c']}');
      }
    }

    try {
      final summary = await _llm.complete(
        cfg: cfg!,
        model: activeModel,
        maxTokens: 500,
        system: 'You compress conversation history. Write a dense factual '
            'summary of the transcript below: decisions made, facts learned, '
            'open questions. Maximum 250 words. No preamble.',
        wire: [Wire.user(transcript.toString())],
      );
      final foldedCount =
          old.where((m) => m['r'] == 'u' || m['r'] == 'a').length;
      session.wire
        ..clear()
        ..addAll([
          Wire.summary(summary.trim()),
          ...recent,
        ]);
      session.wire.first['n'] = foldedCount;
      _rebuildBubbles();
      unawaited(sessions.persist(session));
      notifyListeners();
    } catch (_) {
      // compaction is best-effort; keep history as-is on failure
    }
  }

  String _clip(String s, int n) => s.length <= n ? s : '${s.substring(0, n)}…';

  void _rebuildBubbles() {
    bubbles = deriveBubbles(current?.wire ?? []);
  }

  // ------------------------------------------------------------------
  // updates
  // ------------------------------------------------------------------

  Future<void> checkForUpdates({bool manual = false}) async {
    if (updatePhase == UpdatePhase.checking ||
        updatePhase == UpdatePhase.downloading) {
      return;
    }
    if (!manual &&
        DateTime.now().difference(_lastUpdateCheck) <
            const Duration(minutes: 20)) {
      return;
    }
    _lastUpdateCheck = DateTime.now();
    updatePhase = UpdatePhase.checking;
    lastUpdateNotice = null;
    if (manual) notifyListeners();
    try {
      final info = await _updates.check(appVersion);
      if (info != null) {
        pendingUpdate = info;
        updateDismissed = false;
      } else {
        pendingUpdate = null;
        if (manual) {
          lastUpdateNotice =
              'You are on the latest version ($appVersion).';
        }
      }
      updatePhase = UpdatePhase.idle;
    } catch (e) {
      updatePhase = UpdatePhase.idle;
      if (manual) {
        lastUpdateNotice =
            'Update check failed — check your connection.';
      }
    }
    notifyListeners();
  }

  Future<void> downloadUpdate() async {
    final info = pendingUpdate;
    if (info == null || updatePhase == UpdatePhase.downloading) return;
    updatePhase = UpdatePhase.downloading;
    downloadProgress = 0;
    updateError = null;
    notifyListeners();
    try {
      downloadedApkPath = await _updates.download(
        info.apkUrl,
        (p) {
          downloadProgress = p;
          notifyListeners();
        },
      );
      updatePhase = UpdatePhase.downloaded;
    } catch (e) {
      updatePhase = UpdatePhase.error;
      updateError = e.toString();
    }
    notifyListeners();
  }

  Future<void> installUpdate() async {
    final path = downloadedApkPath;
    if (path == null) return;
    updateError = await _updates.install(path,
        fallbackUrl: pendingUpdate?.releaseUrl);
    if (updateError != null) notifyListeners();
  }

  void dismissUpdate() {
    updateDismissed = true;
    notifyListeners();
  }

  Future<void> _startUpdateWatch() async {
    unawaited(checkForUpdates());
    try {
      _connectivitySub =
          Connectivity().onConnectivityChanged.listen((results) {
        if (results.contains(ConnectivityResult.none)) return;
        unawaited(checkForUpdates());
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _llm.dispose();
    _updates.dispose();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
