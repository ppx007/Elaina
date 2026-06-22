# OpenSpec-Aligned Trellis Context

OpenSpec is the active workflow authority for this repository. Trellis is not
the primary development workflow. Treat Trellis as a supporting context system:

- `.trellis/spec/` stores supplemental engineering conventions and thinking
  guides that can inform OpenSpec-backed work.
- `.trellis/tasks/` stores historical task artifacts. Do not create or route
  new work through Trellis tasks unless the user explicitly asks for Trellis
  archaeology or a future project decision re-enables Trellis task flow.
- `.trellis/workspace/` stores historical session traces and local journals.
- `.trellis/scripts/` may be used for read-only archaeology and context
  discovery, not as the normal implementation workflow.

When this document conflicts with `AGENTS.md`, `README.md`, or
`openspec/specs/**`, the OpenSpec-facing project baseline wins.

---

## Operating Model

1. Start from `AGENTS.md` and active OpenSpec specs.
2. For new behavior, use OpenSpec proposal, task, validation, and archive
   flows.
3. Use `.trellis/spec/` only as supplemental coding guidance.
4. Use the Dart validation CLI in `tools/elaina_tool.dart`; do not resurrect
   PowerShell tooling.
5. Do not commit, push, publish, or configure remotes unless the user
   explicitly asks.

## Current Commands

```powershell
# OpenSpec
openspec.cmd list --json
openspec.cmd validate --all

# Dart and Flutter validation
dart analyze
dart test test/tools
dart run tools\elaina_tool.dart check changed --scope Fast
dart run tools\elaina_tool.dart check module --module <name>
dart run tools\elaina_tool.dart check full
```

## Trellis Spec Usage

Use `.trellis/spec/` when it contains useful local conventions, but keep these
rules tight:

- OpenSpec owns product behavior and cross-layer contracts.
- Trellis specs may document local implementation habits, testing heuristics,
  and historical gotchas.
- If a rule belongs in executable product behavior, update OpenSpec first.
- If a Trellis file says "to fill" or looks like a generic template, do not
  treat it as authoritative.

## Phase Index

This section exists because platform hooks parse the `[workflow-state:*]`
blocks below. The blocks are intentionally OpenSpec-first.

[workflow-state:no_task]
No active Trellis task. This is normal for Elaina. Follow `AGENTS.md`, `README.md`, and OpenSpec. Do not create a Trellis task or route through Trellis phases unless the user explicitly asks for Trellis task workflow or archaeology. For code changes, inspect the repository, implement directly in the current session, and validate with `dart analyze`, the focused Dart CLI check, and `openspec.cmd validate --all` when specs are touched.
[/workflow-state:no_task]

[workflow-state:planning]
A legacy Trellis task is marked `planning`, but OpenSpec remains authoritative. Use the task only as historical context if it is relevant to the user's current request. Do not block on `prd.md`, `implement.jsonl`, or `check.jsonl`; use OpenSpec specs and the repository state as the implementation source of truth.
[/workflow-state:planning]

[workflow-state:planning-inline]
A legacy Trellis task is marked `planning`, but this Codex session should still follow OpenSpec-first inline work. Use Trellis files only as supplemental context, then implement and verify with the current Dart CLI tooling.
[/workflow-state:planning-inline]

[workflow-state:in_progress]
A legacy Trellis task is marked `in_progress`. Treat it as supplemental context, not as an instruction to launch legacy Trellis agents or run old phase gates. Continue from the user's latest request, preserve unrelated work, and validate with the current OpenSpec and Dart CLI commands.
[/workflow-state:in_progress]

[workflow-state:in_progress-inline]
A legacy Trellis task is marked `in_progress`. In Codex inline mode, work directly in the main session. Do not launch legacy Trellis implement/check agents by default. Use `.trellis/spec/` only when it adds concrete local guidance, and validate with `dart analyze`, focused tests or `dart run tools\elaina_tool.dart check changed --scope Fast`, plus OpenSpec validation when applicable.
[/workflow-state:in_progress-inline]

[workflow-state:completed]
A legacy Trellis task is marked `completed`. Do not archive, commit, or update journals unless the user explicitly asks for Trellis cleanup. Continue to follow OpenSpec and the current repository baseline.
[/workflow-state:completed]

## Skill Routing

Trellis skills are optional support tools, not mandatory workflow gates.

| Need | Use |
| --- | --- |
| Refresh project-local Trellis conventions | `trellis-before-dev` |
| Review code against supplemental Trellis conventions | `trellis-check` |
| Preserve a local implementation convention that does not belong in OpenSpec | `trellis-update-spec` |
| Debug repeated failures and capture prevention notes | `trellis-break-loop` |
| Modify Trellis files, hooks, skills, or platform integration | `trellis-meta` |

Do not use Trellis skills to override OpenSpec, AGENTS, README, active user
instructions, or the current Dart CLI validation flow.

## Customizing Trellis

This file is project-local. Keep future edits aligned with these constraints:

- Maintain the `[workflow-state:*]` tags because hooks parse them.
- Keep OpenSpec named as the active workflow authority.
- Keep Trellis task creation opt-in only.
- Keep validation examples on `tools/elaina_tool.dart`.
- Do not reintroduce tracked PowerShell entry points.
