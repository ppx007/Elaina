## Repository Baseline Staging Plan

Date: 2026-06-02
Mode: planning-only
Branch observed: `main`

## Inputs

- Archived review: `openspec/changes/archive/2026-06-02-review-git-status-baseline/status-review.md`
- Guardrail spec: `openspec/specs/git-status-review/spec.md`
- Repository baseline spec: `openspec/specs/repository-baseline/spec.md`
- Current proposal: `openspec/changes/plan-repository-baseline-staging/`

## Read-Only Recheck

Commands run during this apply step:

```powershell
openspec list --json
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/pkpk' status --short --branch
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/pkpk' diff --stat
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/pkpk' diff --cached --stat
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/pkpk' log --oneline -30
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/pkpk' branch --show-current
```

Observed state:

- Active OpenSpec change: `plan-repository-baseline-staging`
- Branch: `main`
- Staged diff: none (`git diff --cached --stat` returned no output)
- Tracked unstaged diff: 48 files, 136 insertions, 5,187 deletions
- History available for style detection: `9e5d657 Initial Celesteria architecture plan`

## Drift From Archived Review

The current status still matches the archived review's major buckets. New untracked drift was observed and must not be staged as baseline:

- `.opencode/tmp-check.ps1`
- `.opencode/tmp-cleanup.cmd`
- `.opencode/tmp-cleanup.js`

These are local cleanup/check artifacts. They require deletion or ignore handling before any future commit approval.

## Style Detection

STYLE DETECTION RESULT
======================
Analyzed: 1 commit from git log

Language profile: English
- Dominant pattern: 1 (100%)
- Secondary pattern: 0 (0%)

Style: PLAIN
- Semantic (`feat:`, `fix:`, etc): 0 (0%)
- Plain: 1 (100%)
- Short: 0 (0%)

Reference examples from repo:
1. `Initial Celesteria architecture plan`

All future commit messages should follow English + plain style unless more history appears before commit execution.

## Branch Context

- Current branch: `main`
- Strategy: new commits only
- Rewrite policy: never rewrite `main`; do not rebase, reset, or fixup existing history during baseline staging.
- Commit creation still requires explicit user approval and is outside this planning change.

## Do-Not-Stage Boundary

Never include these in future staging groups unless separately resolved:

- `.env*`, credentials, private keys, cookies, tokens, or local auth material.
- IDE/user state, OS files, package caches, build output, logs, temporary files, and generated binaries.
- `.opencode/tmp-check.ps1`, `.opencode/tmp-cleanup.cmd`, `.opencode/tmp-cleanup.js`.
- Unresolved `.trellis/tasks/` and `.trellis/workspace/` session history until preservation policy is explicit.
- Any path whose purpose is not mapped to one of the groups below.

## Proposed Commit Groups

This is an advisory staging plan only. Commands are future/manual-only and must not be executed until the user explicitly requests staging or commit creation.

### Commit 1: Establish OpenSpec repository workflow baseline

Proposed message: `Establish OpenSpec repository workflow baseline`

Future staging scope:

- `.gitignore`
- `README.md`
- `AGENTS.md`
- `.opencode/commands/opsx-apply.md`
- `.opencode/commands/opsx-archive.md`
- `.opencode/commands/opsx-explore.md`
- `.opencode/commands/opsx-propose.md`
- `.opencode/skills/openspec-apply-change/`
- `.opencode/skills/openspec-archive-change/`
- `.opencode/skills/openspec-explore/`
- `.opencode/skills/openspec-propose/`
- `openspec/config.yaml`
- `openspec/specs/`
- `openspec/changes/archive/`

Justification: these files establish OpenSpec as the active workflow authority and preserve completed source-of-truth specs and archives as the repository baseline.

Validation gates:

- `openspec validate --all`
- Verify no active change directory is included unless it has first been archived.

### Commit 2: Add Celesteria Dart contract baseline

Proposed message: `Add Celesteria Dart contract baseline`

Future staging scope:

- `analysis_options.yaml`
- `pubspec.yaml`
- `lib/`
- `tools/check_phase0_foundation.ps1`
- `tools/check_player_core.ps1`
- `tools/check_acg_data_experience.ps1`
- `tools/check_detail_library_seasonal.ps1`
- `tools/check_bt_streaming_core.ps1`
- `tools/check_advanced_playback_core.ps1`
- `tools/check_automation_extension_core.ps1`

Justification: these files form the Dart source and validation contract scaffold from the archived Phase 0-6 bootstrap sequence.

Validation gates:

- `dart analyze`
- `powershell -ExecutionPolicy Bypass -File "tools\check_automation_extension_core.ps1"`
- Earlier phase checker scripts if the user wants every phase validated independently.

### Commit 3: Add Celesteria phase documentation baseline

Proposed message: `Add Celesteria phase documentation baseline`

Future staging scope:

- `docs/phase0-foundation.md`
- `docs/phase0-storage-schema.md`
- `docs/phase1-player-core.md`
- `docs/phase2-acg-data-experience.md`
- `docs/phase3-detail-library-seasonal.md`
- `docs/phase4-bt-streaming-core.md`
- `docs/phase5-advanced-playback-core.md`
- `docs/phase6-automation-extension-core.md`
- `docs/next-change-acg-data-experience.md`
- `docs/next-change-detail-library-seasonal.md`
- `docs/next-change-player-core.md`

Justification: these docs explain the contract bootstrap sequence and future planning cut points independently from executable Dart contracts.

Validation gates:

- Confirm each document maps to an archived OpenSpec change or an explicit next-change handoff.

### Commit 4: Retire Trellis OpenCode agents and commands

Proposed message: `Retire Trellis OpenCode agents and commands`

Future staging scope:

- `.opencode/agents/trellis-check.md`
- `.opencode/agents/trellis-implement.md`
- `.opencode/agents/trellis-research.md`
- `.opencode/commands/trellis/continue.md`
- `.opencode/commands/trellis/finish-work.md`

Justification: these tracked deletions remove obsolete Trellis command routing after OpenSpec became the active workflow authority.

Validation gates:

- Confirm replacement OpenSpec commands exist in `.opencode/commands/opsx-*.md`.

### Commit 5: Retire Trellis OpenCode runtime hooks

Proposed message: `Retire Trellis OpenCode runtime hooks`

Future staging scope:

- `.opencode/lib/session-utils.js`
- `.opencode/lib/trellis-context.js`
- `.opencode/plugins/inject-subagent-context.js`
- `.opencode/plugins/inject-workflow-state.js`
- `.opencode/plugins/session-start.js`

Justification: these tracked deletions remove the old Trellis context injection/runtime path separately from command and skill definitions.

Validation gates:

- Confirm no retained OpenSpec command references deleted Trellis runtime modules.

### Commit 6: Retire Trellis OpenCode skills

Proposed message: `Retire Trellis OpenCode skills`

Future staging scope:

- `.opencode/skills/trellis-before-dev/`
- `.opencode/skills/trellis-brainstorm/`
- `.opencode/skills/trellis-break-loop/`
- `.opencode/skills/trellis-check/`
- `.opencode/skills/trellis-meta/`
- `.opencode/skills/trellis-spec-bootstarp/`
- `.opencode/skills/trellis-update-spec/`

Justification: these tracked deletions are a large skill-tree removal and should remain separate from smaller command/runtime cleanup commits for reviewability.

Validation gates:

- Confirm replacement OpenSpec skills exist in `.opencode/skills/openspec-*`.
- Confirm root `AGENTS.md` marks Trellis as legacy context rather than active workflow.

### Commit 7: Preserve or resolve Trellis task history

Proposed message: `Preserve Trellis task history`

Future staging scope requiring human decision:

- `.trellis/tasks/06-01-save-elaina-player-architecture-plan/`
- `.trellis/tasks/06-01-bootstrap-celesteria-implementation/`
- `.trellis/tasks/06-01-opencode-trellis-omo-routing/`

Justification: these files contain task/session history that may be useful project context, but they are not automatically source-of-truth code or specs.

Required decision before staging:

- Commit as historical context.
- Move selected content into docs and leave task logs untracked.
- Ignore/remove as local session state.

Validation gates:

- Confirm no private session details or machine-local state should be excluded.

### Commit 8: Review architecture plan updates

Proposed message: `Update Celesteria architecture plan`

Future staging scope:

- `docs/celesteria-architecture-plan.md`

Justification: the architecture plan is the durable product roadmap and should remain independently reviewable from workflow and contract scaffolding.

Validation gates:

- Confirm edits preserve the 8-layer isolation rules.
- Confirm UI still does not depend directly on MPV/VLC/Bangumi/Dandanplay/libtorrent/yuc.wiki.
- Confirm online source parsing remains outside the core playback prerequisite path.

## File Count And Atomicity Check

The dirty tree is much larger than ten files, so one giant commit is invalid. This plan proposes eight commit groups, with the largest groups split by concern:

- OpenSpec workflow baseline and archives.
- Dart executable contracts and validation tools.
- Documentation baseline.
- Trellis command/agent deletion.
- Trellis runtime hook deletion.
- Trellis skill deletion.
- Trellis task-history preservation decision.
- Architecture plan review.

Every group with three or more files has a justification above. Future execution should re-check exact file counts before staging; if any group has grown or mixes concerns, split it further.

## Future Manual Commands

These are review commands for a future approved staging step. They are not executed by this change:

```powershell
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/pkpk' status --short --branch
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/pkpk' diff --stat
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/pkpk' add -n <pathspecs-for-one-group>
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/pkpk' diff --cached --stat
openspec validate --all
dart analyze
powershell -ExecutionPolicy Bypass -File "tools\check_automation_extension_core.ps1"
```

Future execution must stage one group at a time and verify `git diff --cached --stat` before every commit.

## Blockers Before Actual Commit Execution

- Decide how to handle `.trellis/tasks/` and any `.trellis/workspace/` material.
- Remove or ignore `.opencode/tmp-check.ps1`, `.opencode/tmp-cleanup.cmd`, and `.opencode/tmp-cleanup.js`.
- Archive `plan-repository-baseline-staging` before including its artifacts in a baseline commit.
- Re-run status and validation immediately before any approved staging action.
