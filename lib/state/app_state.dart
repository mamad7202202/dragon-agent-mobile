import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/llm.dart';
import '../data/memory.dart';
import '../data/models.dart';
import '../data/sessions.dart';

class Settings {
  double temperature;
  int maxTokens;
  int compactionAfter; // fold after this many wire entries
  bool memoryEnabled;

  Settings({
    this.temperature = 0.7,
    this.maxTokens = 2048,
    this.compactionAfter = 36,
    this.memoryEnabled = true,
  });

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'max_tokens': maxTokens,
        'compaction_after': compactionAfter,
        'memory_enabled': memoryEnabled,
      };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
        temperature: (j['temperature'] as num?)?.toDouble() ?? 0.7,
        maxTokens: (j['max_tokens'] as num?)?.toInt() ?? 2048,
        compactionAfter: (j['compaction_after'] as num?)?.toInt() ?? 36,
        memoryEnabled: j['memory_enabled'] as bool? ?? true,
      );
}

/// Central app controller.
class AppState extends ChangeNotifier {
  final LlmClient _llm = LlmClient();
  final MemoryStore memory = MemoryStore();
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

  // navigation intents consumed by UI
  int memoriesOpenTick = 0;

  bool get configured =>
      providers.isNotEmpty &&
      providers[activeProvider] != null &&
      activeModel.isNotEmpty;

  ProviderCfg? get cfg => providers[activeProvider];

  /// True once init() finished loading persisted state.
  bool ready = false;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await memory.load();
    await sessions.loadIndex();

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

    // resume latest session
    if (configured && sessions.metas.isNotEmpty) {
      try {
        current = await sessions.open(sessions.metas.first.id);
        _rebuildBubbles();
      } catch (_) {}
    }
    ready = true;
    notifyListeners();
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
    try {
      await memory.saveFacts();
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
  // chat
  // ------------------------------------------------------------------

  Future<void> newSession() async {
    if (busy) return;
    current = await sessions.create();
    bubbles = [];
    liveText = null;
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
        final f = memory.add(fact);
        appendLocalBubble(Bubble(
          id: 'cmd-${f.id}',
          kind: BubbleKind.toolUse,
          toolName: 'save_memory',
          toolArgs: '{"text": "$fact"}',
        ));
        return true;
      case '/forget':
        final id = input.trim().substring('/forget'.length).trim();
        final ok = memory.remove(id);
        appendLocalBubble(Bubble(
          id: 'cmd-forget-$id',
          kind: ok ? BubbleKind.assistant : BubbleKind.error,
          text: ok ? 'Fact `$id` forgotten.' : 'No fact matching `$id`.',
        ));
        return true;
      case '/clear':
        memory.clear();
        appendLocalBubble(const Bubble(
          id: 'cmd-clear',
          kind: BubbleKind.assistant,
          text: 'All facts cleared. MEMORY.md is kept — edit it in **Memories → Rules**.',
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

    // user turn
    current!.wire.add(Wire.user(text));
    bubbles = [
      ...bubbles,
      Bubble(id: 'u${current!.wire.length}', kind: BubbleKind.user, text: text),
    ];
    unawaited(sessions.persist(current!));
    notifyListeners();

    await runTurn();
  }

  /// Agent loop: stream a turn, execute memory tools, repeat up to N rounds.
  Future<void> runTurn() async {
    final session = current!;
    busy = true;
    liveText = null;
    var assistantBuf = StringBuffer();

    void flush({bool done = false}) {
      liveText = done ? null : assistantBuf.toString();
      notifyListeners();
    }

    try {
      for (var round = 0; round < 4; round++) {
        assistantBuf = StringBuffer();
        final calls = <ToolCall>[];

        await _llm.streamTurn(
          cfg: cfg!,
          model: activeModel,
          system: _buildSystem(session),
          wire: session.wire,
          temperature: settings.temperature,
          maxTokens: settings.maxTokens,
          onEvent: (e) {
            switch (e) {
              case DeltaText():
                assistantBuf.write(e.text);
                flush();
              case ToolRequested():
                calls.add(e.call);
              case ToolFinished():
                break;
            }
          },
        );

        final text = assistantBuf.toString().trim();

        if (calls.isEmpty) {
          session.wire.add(Wire.assistant(text));
          bubbles = [...bubbles, Bubble(
            id: 'a${session.wire.length}',
            kind: BubbleKind.assistant,
            text: text.isEmpty ? '_(empty response)_' : text,
          )];
          break;
        }

        // record any text before tool use
        if (text.isNotEmpty) {
          session.wire.add(Wire.assistant(text));
          bubbles = [...bubbles, Bubble(
            id: 'at${session.wire.length}',
            kind: BubbleKind.assistant,
            text: text,
          )];
        }

        // execute tools
        final executed = <Map<String, String>>[];
        for (final call in calls) {
          final out = _execTool(call);
          executed.add({'id': call.id, 'name': call.name, 'out': out});
          bubbles = [...bubbles, Bubble(
            id: 'tool-${call.id}',
            kind: BubbleKind.toolUse,
            toolName: call.name,
            toolArgs: call.argsJson,
          )];
        }
        session.wire.add(Wire.assistantToolCalls(
          calls.map((c) => {'id': c.id, 'name': c.name, 'args': c.argsJson}).toList(),
        ));
        session.wire.add(Wire.toolResults(executed));
        await memory.saveFacts();
      }

      unawaited(sessions.persist(session));
      await maybeCompact();
    } on LlmException catch (e) {
      bubbles = [...bubbles, Bubble(
        id: 'err${DateTime.now().millisecondsSinceEpoch}',
        kind: BubbleKind.error,
        text: e.message,
      )];
    } catch (e) {
      bubbles = [...bubbles, Bubble(
        id: 'err${DateTime.now().millisecondsSinceEpoch}',
        kind: BubbleKind.error,
        text: e.toString(),
      )];
    } finally {
      busy = false;
      liveText = null;
      notifyListeners();
    }
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
            importance:
                ((args['importance'] as num?)?.toDouble()) ?? 0.5,
          );
          return jsonEncode({'ok': true, 'id': fact.id});
        case 'forget_memory':
          final ok = memory.remove(args['id'] as String? ?? '');
          return jsonEncode({'ok': ok});
        default:
          return jsonEncode({'error': 'unknown tool ${call.name}'});
      }
    } catch (e) {
      return jsonEncode({'error': e.toString()});
    }
  }

  String _buildSystem(SessionData session) {
    final buf = StringBuffer();
    buf.writeln('You are Dragon Agent, a sharp, warm and concise AI assistant '
        'living inside the user\'s pocket. You have a persistent memory.');
    buf.writeln();
    buf.writeln('MEMORY TOOLS — you carry two tools:');
    buf.writeln('- save_memory(text, importance): store durable facts about '
        'the user, their projects or decisions. Use it whenever you notice '
        'something worth remembering across sessions (preferences, names, '
        'goals, corrections). Do not store trivial chatter.');
    buf.writeln('- forget_memory(id): remove an obsolete fact by id prefix.');
    if (settings.memoryEnabled) {
      final facts = memory.all;
      if (facts.isNotEmpty) {
        buf.writeln();
        buf.writeln('[KNOWN FACTS]');
        for (final f in facts) {
          buf.writeln('- (${f.id}) ${f.content}');
        }
      }
      final procedural = memory.proceduralBlock();
      if (procedural != null) {
        buf.writeln().writeln(procedural);
      }
    }
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
    // find split index over full wire so that recent conversational turns stay
    final idxUserAssistant = <int>[];
    for (var i = 0; i < session.wire.length; i++) {
      final r = session.wire[i]['r'];
      if (r == 'u' || r == 'a') idxUserAssistant.add(i);
    }
    if (idxUserAssistant.length <= keepRecent + 2) return;
    final cutWireIdx = idxUserAssistant[idxUserAssistant.length - keepRecent];

    final old = session.wire.sublist(0, cutWireIdx);
    final recent = session.wire.sublist(cutWireIdx);

    final transcript = StringBuffer('Transcript of an earlier conversation:\n\n');
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

  @override
  void dispose() {
    _llm.dispose();
    super.dispose();
  }
}
