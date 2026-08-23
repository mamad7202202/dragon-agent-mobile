<div align="center">

```
██████╗ ██████╗  █████╗  ██████╗  ██████╗ ███╗   ██╗
██╔══██╗██╔══██╗██╔══██╗██╔════╝ ██╔═══██╗████╗  ██║
██║  ██║██████╔╝███████║██║  ███╗██║   ██║██╔██╗ ██║
██║  ██║██╔══██╗██╔══██║██║   ██║██║   ██║██║╚██╗██║
██████╔╝██║  ██║██║  ██║╚██████╔╝╚██████╔╝██║ ╚████║
╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝

    M O B I L E
```

**The dragon, in your pocket.**
*A beautiful cross-platform (Android · iOS) companion to the desktop
[dragon-agent](https://github.com/mamad7202202/dragon-agent) — same hybrid
memory, zero desktop required.*

[![Build & Release](https://github.com/mamad7202202/dragon-agent-mobile/actions/workflows/build.yml/badge.svg)](https://github.com/mamad7202202/dragon-agent-mobile/actions/workflows/build.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-ff6a3d.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter)](https://flutter.dev)

</div>

---

## Why this app

Most mobile AI chat apps forget you the moment you close them. **Dragon Agent
Mobile** ports the desktop app's *hybrid memory system* to your pocket:

- **Semantic memory** — discrete facts (`facts.json`), recalled per-turn with
  lexical cosine scoring × importance × two-week recency decay. No vector DB,
  works fully offline.
- **Procedural memory** — a plain `MEMORY.md` of standing rules, always loaded.
- **Episodic memory** — every session is a resumable transcript on device.
- **Automatic compaction** — long chats are folded into dense LLM summaries so
  context never overflows.

## Highlights

| | |
|---|---|
| **Bring your own key** | Google AI Studio, OpenRouter, OpenAI, Anthropic (native), Groq, DeepSeek, Ollama / LM Studio over LAN, or any OpenAI-compatible endpoint |
| **Real tool use** | The agent calls `save_memory` / `forget_memory` on its own; live tool-activity chips show what it's doing |
| **Streaming** | Token-by-token responses with SSE for both OpenAI-compatible and Anthropic-native protocols |
| **Ember-lit UI** | Material 3 dark theme, molten-orange gradients, animated flame logo, smooth 60 fps transitions |
| **Private by default** | Keys, memories and transcripts live only on your device |

## Install

Grab the newest build straight from CI:

1. **Android** → [rolling `latest` release](https://github.com/mamad7202202/dragon-agent-mobile/releases/tag/latest)
   → `Dragon-Agent-android-arm64.apk` (or `-universal`) → sideload.
2. **iOS** → `Dragon-Agent-iOS-unsigned.ipa` from the same release.
   Unsigned IPA: install via [AltStore/Sideloadly](https://sideloadly.io) or sign it yourself in Xcode.

Every push to `main` rebuilds both artifacts automatically via GitHub Actions —
nothing is built on your machine.

## First launch

A three-step wizard gets you talking in under a minute:

1. **Pick a provider** — Google, OpenRouter, OpenAI, Anthropic, Groq, DeepSeek,
   Ollama, LM Studio or custom.
2. **Connect** — base URL is pre-filled; paste your API key (stored only on
   device). Local-model users: replace `localhost` with your PC's LAN IP.
3. **Pick a model** — suggested chips per provider, or type any model id.

## In-chat commands

```
/new              start a fresh session
/remember <fact>  pin a long-term fact
/forget <id>      delete a fact by id prefix
/memories         open the memory manager
/clear            wipe all facts (MEMORY.md kept)
/help             list commands
```

Tap the model chip in the top bar (`/model` equivalent) to switch models mid-session.

## Architecture

```
lib/
├── core/
│   ├── presets.dart        provider presets (mirrors desktop presets.rs)
│   └── theme.dart          ember-lit Material 3 theme
├── data/
│   ├── llm.dart            streaming client: OpenAI-compat + Anthropic-native + tools
│   ├── memory.dart         semantic facts + MEMORY.md + cosine recall scoring
│   ├── models.dart         neutral wire format → display bubbles
│   └── sessions.dart       episodic JSON transcripts
├── state/
│   └── app_state.dart      agent loop, slash commands, auto-compaction
└── ui/
    ├── screens/            chat, setup wizard, memories, sessions, settings
    └── widgets/            bubbles, composer, flame logo, ember particles
```

### Memory scoring (identical formula to desktop)

```
score = tf_cosine(query, fact)
      × (0.55 + 0.45 × importance)
      × (0.7 + 0.3 × recency)        recency = 1 / (1 + age_days / 14)
```

Top-k facts are injected into the system prompt each turn; old turns fold into
an LLM summary once history passes the compaction threshold.

## Building

You don't have to. GitHub Actions builds everything:

- `android` job — JDK 21 + Flutter stable → universal + arm64 release APKs
- `ios` job — Flutter stable on macOS → unsigned IPA
- `release` job — attaches both to the rolling [`latest`](https://github.com/mamad7202202/dragon-agent-mobile/releases/tag/latest)
  release; `v*` tags get formal releases.

Platform folders (`android/`, `ios/`) are intentionally not committed;
CI generates them with `flutter create .` and applies manifest patches
(INTERNET permission, cleartext for LAN models, display name).

To build locally anyway: `flutter create . --project-name dragon_agent_mobile --platforms android,ios && flutter build apk --release`.

## Roadmap

- [ ] Voice input
- [ ] Embedding-backed semantic recall (optional, provider-side)
- [ ] Home-screen widget for quick capture
- [ ] Signed Play Store / TestFlight builds

## Author

**mamad720220** · [Telegram @mamad720220](https://t.me/mamad720220)

Desktop sibling: [mamad7202202/dragon-agent](https://github.com/mamad7202202/dragon-agent)

Licensed under [MIT](LICENSE).
