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
[![Docs](https://img.shields.io/badge/docs-mamad7202202.github.io%2Fdragon--agent--mobile-ff6a3d)](https://mamad7202202.github.io/dragon-agent-mobile/)
[![License: MIT](https://img.shields.io/badge/license-MIT-ff6a3d.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter)](https://flutter.dev)

**📖 Full documentation & landing page:
[mamad7202202.github.io/dragon-agent-mobile](https://mamad7202202.github.io/dragon-agent-mobile/)**
— getting started, providers, memory engines, tools, commands, FAQ.

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
| **Deep thinking** | Reasoning-effort levels (Off → Deep) with a collapsible thought-process viewer; native Anthropic thinking budgets |
| **Web search** | Native per provider — OpenRouter `:online`, Anthropic server-side `web_search` |
| **Token awareness** | Per-message usage badge reported by the provider — subtle, never noisy |
| **Approval gate** | Sensitive tools (forget/delete/rules) pause for an inline Allow / Always-this-session / Deny card |
| **Real tool use** | Memory tools, exact calculator, datetime, device info — live activity chips with status & results |
| **Two memory engines** | Hybrid scored facts **or** the new token-efficient Outline (infographic) memory — switchable in Settings |
| **Light & dark** | Full theme modes with liquid-glass surfaces, floating composer and a soft bottom fade into the typing bar |
| **Streaming** | Token-by-token responses with SSE for both OpenAI-compatible and Anthropic-native protocols |
| **Auto-update** | Checks GitHub releases on connect; one tap downloads & installs over the current version — no uninstall needed |
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

## Updating

The app updates itself:

1. Whenever the device comes online (and once on launch), it checks the
   [rolling `latest` release](https://github.com/mamad7202202/dragon-agent-mobile/releases/tag/latest)
   via the GitHub API.
2. If a newer `X.Y.Z` exists, a banner slides in — tap **به‌روزرسانی**.
3. The APK downloads with live progress, then the system installer opens.
   Installs stack on top of the current version (same signing key + same
   `applicationId`), so you never uninstall first.
4. Manual check lives in **Settings → Check for updates**. On iOS the banner
   opens the releases page instead (in-app self-update isn't possible there).

## Versioning

- Source of truth: `version: X.Y.Z+N` in `pubspec.yaml` (bump on every change set).
- Every push to `main` is tagged `vX.Y.Z` automatically and gets its own
  formal release, alongside the rolling `latest`.
- The in-app updater compares semver, so `+N` build numbers never trigger
  false updates.

### Signing

`signing/release.keystore` is committed to the repo and used by CI
(`apksigner`, alias `dragon`, storepass `dragonagent2026`). It's a public,
dedicated sideloading key — that's what guarantees update-over-install works
across builds. Don't reuse it anywhere sensitive.

## Architecture

```
lib/
├── core/
│   ├── presets.dart        provider presets (mirrors desktop presets.rs)
│   └── theme.dart          ember-lit Material 3 theme (light + dark)
├── data/
│   ├── llm.dart            streaming client: thinking, web search, usage, tools
│   ├── memory.dart         semantic facts + MEMORY.md + cosine recall scoring
│   ├── graph_memory.dart   outline (infographic) memory — sections & bullets
│   ├── models.dart         neutral wire format → display bubbles
│   └── sessions.dart       episodic JSON transcripts
├── services/
│   └── update_service.dart GitHub releases check, download & install
├── state/
│   └── app_state.dart      agent loop, tool gate, slash commands, compaction
└── ui/
    ├── screens/            chat, setup wizard, memories, sessions, settings
    └── widgets/            bubbles, glass surfaces, code blocks, flame logo
docs/                       GitHub Pages site (landing + full documentation)
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
