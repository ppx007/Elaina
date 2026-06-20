<!-- REPOSITORY-BASELINE:START -->
# Active Workflow Authority

OpenSpec is the active workflow authority for this project. Use OpenSpec proposal, apply, validate, and archive flows for new work.

The Trellis block below is retained as legacy context because `.trellis/` still contains historical workflow, task, spec, and workspace material. Do not treat Trellis as the primary workflow unless a future explicit change re-enables it.

<!-- REPOSITORY-BASELINE:END -->

<!-- TRELLIS:START -->
# Trellis Instructions

These instructions are retained for legacy context only.

Historical Trellis material lives under `.trellis/`:

- `.trellis/workflow.md` - legacy development phases and skill routing
- `.trellis/spec/` - historical package/layer guideline drafts and thinking guides
- `.trellis/workspace/` - legacy developer journals and session traces
- `.trellis/tasks/` - historical task PRDs, research, and jsonl context

Do not create or route new work through Trellis unless a future explicit project decision re-enables it. Prefer OpenSpec commands and docs for current work.

If a legacy Trellis command is needed for archaeology, use `.trellis/scripts/` instead of manually rewriting Trellis internal state.

<!-- TRELLIS:END -->

# Project Knowledge Base

## Overview

Elaina (code name 1017) is an end-side-first cross-platform ACG player. The current repository is a Flutter/Dart contract scaffold with native playback, provider, streaming, storage, network, diagnostics, and UI boundary contracts.

The project is no longer a source-free planning repository. `lib/`, `test/`, `tools/`, `docs/`, and `openspec/` are project source-of-truth areas.

## Structure

```text
elaina/
├── AGENTS.md          # Current agent-facing project baseline
├── README.md          # Human project entrypoint and validation commands
├── analysis_options.yaml
├── pubspec.yaml
├── lib/               # Dart contract scaffolding and runtime slices
├── test/              # Dart/Flutter contract and runtime tests
├── tools/             # Runtime validation scripts and PowerShell wrappers
├── docs/              # Architecture, phase, decision, guide, and process docs
├── openspec/          # Active OpenSpec specs and archived changes
├── .trellis/          # Legacy Trellis context, not the active workflow
├── .agents/           # Legacy/project-scoped agent skills
├── .codex/            # Codex configuration
├── .gemini/           # Gemini configuration
├── .opencode/         # OpenCode configuration and local indexing state
└── .sisyphus/         # Local continuation/runtime state
```

## Where To Look

| Task | Location |
|------|----------|
| Current baseline and validation | `README.md` |
| Architecture decisions | `docs/elaina-architecture-plan.md` |
| Phase implementation docs | `docs/phase*.md` |
| Stable process docs | `docs/process/` |
| Cross-layer thinking | `docs/guides/cross-layer-thinking.md` |
| Code reuse patterns | `docs/guides/code-reuse-thinking.md` |
| Active specs | `openspec/specs/*/spec.md` |
| Archived changes | `openspec/changes/archive/` |
| Public Dart exports | `lib/elaina.dart` |
| Local validation scripts | `tools/check_*.ps1` and `tools/*_runtime_check.dart` |

## Conventions

- Use OpenSpec for new changes: proposal, apply, validate, archive.
- Keep Trellis as legacy context only unless explicitly re-enabled.
- Spec and code documentation should be English unless a specific architecture note intentionally remains Chinese.
- Windows shell is PowerShell 5.1; prefer separate commands or `;` over Bash-style `&&`.
- Use `openspec.cmd` from PowerShell when `openspec.ps1` is blocked by execution policy.
- Run OpenSpec validation and Dart analysis before reporting a baseline as ready.

## Architecture Rules

- Preserve 8-layer isolation: UI / Domain / Playback / Provider / Gateway / Storage / Streaming / Network.
- UI must not directly depend on MPV, VLC, Bangumi, Dandanplay, libtorrent, or yuc.wiki.
- External integrations enter through PlayerAdapter, Provider, FeedSource, Profile, Gateway, or other declared extension points.
- Online source parsing must not become a prerequisite for the core playback loop.
- Captcha auto-cracking is forbidden; support only manual completion plus same-origin session backfill.
- Treat yuc.wiki as one RSS FeedSource, not a privileged scraper.
- iOS does not promise long-running background BT download.

## Runtime Red Lines

- CapabilityMatrix declares feature availability; UI only exposes capabilities supported by the current environment.
- A/V drift target is under 40 ms; drift over 120 ms must trigger degradation.
- Advanced rendering must integrate with frame budget, AV sync guard, and diagnostics surfaces.
- Degradation must prefer deterministic capability and budget decisions over UI-side special cases.

## Commands

```powershell
# OpenSpec workflow
openspec.cmd list --json
openspec.cmd new change "<change-name>"
openspec.cmd status --change "<change-name>" --json
openspec.cmd instructions apply --change "<change-name>" --json
openspec.cmd validate --all
openspec.cmd archive "<change-name>" -y

# Dart/Flutter validation
dart analyze
powershell -ExecutionPolicy Bypass -File "tools\check_automation_extension_core.ps1"
```

## Notes

- The Step 1-30 contract bootstrap has been archived into `openspec/changes/archive/` and synced into `openspec/specs/`.
- Phase 0-6 runtime and contract scaffolding exist in `lib/`, `test/`, and `tools/`.
- `.trellis/tasks/06-*` directories are legacy historical material. Do not delete or commit them casually; use local Git exclude when they are only dirty-tree noise.
- `.opencode/index/*`, `.omo/run-continuation/*`, local IDE settings, and generated caches are local runtime state unless a specific change says otherwise.
- Repository policy: do not commit, push, configure remotes, or publish without explicit user confirmation.
