---
name: trellis-check
description: "Checks recent code against OpenSpec, current Dart/Flutter validation, and any relevant supplemental Trellis conventions. Use before reporting implementation work as complete."
---

# OpenSpec-First Quality Check

This repository no longer uses Trellis as the primary workflow. Use this skill
as a compact review checklist that combines active OpenSpec requirements with
optional Trellis convention checks.

## Step 1: Identify Changes

```powershell
git status --short
git diff --name-only HEAD
```

Separate files you edited from unrelated dirty files. Do not revert or commit
unrelated user work.

## Step 2: Check Active Authorities

- Read `AGENTS.md` and the relevant OpenSpec specs or active change.
- Read `.trellis/spec/**/index.md` only when it contains concrete guidance for
  the changed files.

## Step 3: Run Focused Validation

Default validation:

```powershell
dart analyze
dart run tools\elaina_tool.dart check changed --scope Fast
```

Use module or full gates only when the change justifies them:

```powershell
dart run tools\elaina_tool.dart check module --module <name>
dart run tools\elaina_tool.dart check full
openspec.cmd validate --all
```

Run `openspec.cmd validate --all` whenever specs or OpenSpec changes were
touched.

## Step 4: Review

- No magic values introduced.
- No broad fallback or over-defensive catch-all logic.
- Boundaries remain intact across UI, domain, provider, gateway, storage,
  playback, streaming, and network layers.
- Tests cover behavior, not private layout details or timing guesses.
- Documentation updates belong in OpenSpec first; Trellis specs are only
  supplemental local convention notes.

Fix concrete issues directly, then rerun the relevant checks.
