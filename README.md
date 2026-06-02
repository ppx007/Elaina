# Celesteria

Celesteria (code name 1017) is an end-side-first cross-platform ACG player planned around Flutter/Dart frontend contracts and native playback/download adapters.

## Current Baseline

- OpenSpec is the active workflow authority for proposal, apply, validation, and archive work.
- The Step 1-30 contract bootstrap has been archived into `openspec/changes/archive/` and synced into `openspec/specs/`.
- Dart contract scaffolding lives under `lib/` and is validated with `dart analyze` plus project checker scripts in `tools/`.
- Trellis files remain in `.trellis/` as legacy context only; do not route new work through Trellis unless a future change explicitly re-enables it.

## Workflow

Use OpenSpec for new changes:

```powershell
openspec list --json
openspec new change "<change-name>"
openspec status --change "<change-name>" --json
openspec instructions apply --change "<change-name>" --json
openspec validate --all
openspec archive "<change-name>" -y
```

Run local validation before reporting a baseline as ready:

```powershell
openspec validate --all
dart analyze
powershell -ExecutionPolicy Bypass -File "tools\check_automation_extension_core.ps1"
```

## Repository Policy

- Do not commit, push, configure remotes, or publish without an explicit user request.
- Create or update `.gitignore` before staging files.
- Preserve `openspec/`, `docs/`, `lib/`, `tools/`, root manifests, and agent instructions as project source of truth.
- Treat `.trellis/` as legacy context pending an explicit preservation or deletion decision.
