## Refreshed Repository Baseline Staging Plan

Date: 2026-06-02
Mode: planning-only
Branch observed: `main`

## Inputs

- Current change: `openspec/changes/refresh-baseline-staging-plan/`
- Archived status review: `openspec/changes/archive/2026-06-02-review-git-status-baseline/status-review.md`
- Archived staging plan: `openspec/changes/archive/2026-06-02-plan-repository-baseline-staging/staging-plan.md`
- Guardrail specs:
  - `openspec/specs/git-status-review/spec.md`
  - `openspec/specs/repository-baseline-staging-plan/spec.md`
  - `openspec/specs/trellis-context-extraction/spec.md`
  - `openspec/specs/markdown-lsp-configuration/spec.md`

## Read-Only Recheck

Commands run during this apply step:

```powershell
openspec list --json
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/elaina' status --short --branch
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/elaina' status --porcelain=v1 -uall
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/elaina' diff --name-status
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/elaina' diff --stat
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/elaina' diff --cached --stat
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/elaina' ls-files --others --exclude-standard
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/elaina' branch --show-current
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/elaina' log --oneline -10
```

Observed state:

- Active OpenSpec change: `refresh-baseline-staging-plan`
- Branch: `main`
- Staged diff: none (`git diff --cached --stat` returned no output)
- Tracked unstaged diff: 48 files, 136 insertions, 5,187 deletions
- Recent history available for style detection: `9e5d657 Initial Elaina architecture plan`
- Read-only-only confirmation: no staging, deletion, commit, reset, checkout, remote configuration, push, or publish command was run.

## Drift From Archived Plans

### Resolved drift

- `.opencode/tmp-check.ps1`, `.opencode/tmp-cleanup.cmd`, and `.opencode/tmp-cleanup.js` no longer appear in `git ls-files --others --exclude-standard` because root `.gitignore` now ignores `.opencode/tmp-*`.
- Trellis task-history blocker is partially resolved by extracted docs:
  - `docs/process/trellis-legacy-extraction.md`
  - `docs/process/repository-baseline-cleanup.md`
  - `docs/guides/cross-layer-thinking.md`
  - `docs/guides/code-reuse-thinking.md`
  - `docs/decisions/phase0-implementation-scope.md`
- Markdown diagnostics are operational through user-level OpenCode/OMO config, and the repository now has an archived OpenSpec record plus synced spec for that work.

### New or expanded drift

- Active change directory now appears under `openspec/changes/refresh-baseline-staging-plan/`; it is not eligible for staging until this change is archived.
- New OpenSpec archive/spec material now appears as untracked baseline candidates:
  - `openspec/changes/archive/2026-06-02-trellis-extract-valuable-to-docs-confirm-garbage/`
  - `openspec/changes/archive/2026-06-02-configure-markdown-lsp/`
  - `openspec/specs/trellis-context-extraction/spec.md`
  - `openspec/specs/markdown-lsp-configuration/spec.md`
- New Trellis extraction docs under `docs/process/`, `docs/guides/`, and `docs/decisions/` belong with documentation/baseline planning rather than raw Trellis task logs.

## Do-Not-Stage Boundary

Do not stage these during any future baseline execution unless separately approved and reviewed:

- `.env*`, credentials, private keys, cookies, tokens, local auth material, or local secrets.
- IDE/user state, OS files, caches, logs, build output, generated binaries, package caches, and ignored temporary files.
- `.opencode/tmp-*`; they are ignored and documented as local cleanup artifacts.
- Active OpenSpec change directories, including `openspec/changes/refresh-baseline-staging-plan/`, until archived.
- Unresolved `.trellis/workspace/` session records.
- Raw `.trellis/tasks/` history unless the user explicitly chooses to preserve it as repository history.
- Any file whose purpose cannot be mapped to one of the groups below.

## Staging Safeguards For Future Execution

This plan is advisory only. Future staging/commit execution must use exact pathspecs and dry-runs.

Forbidden for the large dirty tree:

- `git add -A`
- `git add .`
- `git commit -a`
- any blanket path that stages unrelated tracked deletions plus untracked baselines at once

Required loop for each future group:

```powershell
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/elaina' status --porcelain=v1 -uall
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/elaina' add -n <explicit-pathspecs-for-one-group>
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/elaina' add <explicit-pathspecs-for-one-group>
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/elaina' diff --cached --stat
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/elaina' diff --cached -- <explicit-pathspecs-for-one-group>
```

Commit creation remains outside this change and still requires explicit user approval.

## Proposed Commit Groups

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

Justification: these files establish OpenSpec as the active workflow authority and preserve completed source-of-truth specs and archived changes.

Validation gates:

- `openspec validate --all`
- Confirm `openspec list --json` returns no active changes before staging this group.
- Confirm no active `openspec/changes/<name>/` directory is included.

### Commit 2: Add Elaina Dart contract baseline

Proposed message: `Add Elaina Dart contract baseline`

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

Justification: these files form the executable Dart contract scaffold and validation scripts created by the Phase 0-6 bootstrap sequence.

Validation gates:

- `dart analyze`
- `powershell -ExecutionPolicy Bypass -File "tools\check_automation_extension_core.ps1"`
- Optional: run earlier phase checker scripts independently for a narrower audit.

### Commit 3: Add Elaina phase documentation baseline

Proposed message: `Add Elaina phase documentation baseline`

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

Justification: these docs explain the contract bootstrap sequence and next-change handoffs separately from executable source contracts.

Validation gates:

- Markdown LSP diagnostics on staged docs.
- Confirm each phase document maps to an archived OpenSpec change or explicit handoff.

### Commit 4: Add extracted Trellis context docs

Proposed message: `Add extracted Trellis context docs`

Future staging scope:

- `docs/process/trellis-legacy-extraction.md`
- `docs/process/repository-baseline-cleanup.md`
- `docs/guides/cross-layer-thinking.md`
- `docs/guides/code-reuse-thinking.md`
- `docs/decisions/phase0-implementation-scope.md`

Justification: these files extract durable Trellis decisions and reusable guides into stable docs so raw Trellis task logs do not need to be treated as the primary source of truth.

Validation gates:

- Markdown LSP diagnostics on these docs.
- Confirm docs reference source Trellis paths and do not copy raw session traces wholesale.

### Commit 5: Retire Trellis OpenCode agents and commands

Proposed message: `Retire Trellis OpenCode agents and commands`

Future staging scope:

- `.opencode/agents/trellis-check.md`
- `.opencode/agents/trellis-implement.md`
- `.opencode/agents/trellis-research.md`
- `.opencode/commands/trellis/continue.md`
- `.opencode/commands/trellis/finish-work.md`

Justification: these tracked deletions remove obsolete Trellis command/agent routing after OpenSpec became the active workflow authority.

Validation gates:

- Confirm replacement OpenSpec commands exist in `.opencode/commands/opsx-*.md`.

### Commit 6: Retire Trellis OpenCode runtime hooks

Proposed message: `Retire Trellis OpenCode runtime hooks`

Future staging scope:

- `.opencode/lib/session-utils.js`
- `.opencode/lib/trellis-context.js`
- `.opencode/plugins/inject-subagent-context.js`
- `.opencode/plugins/inject-workflow-state.js`
- `.opencode/plugins/session-start.js`

Justification: these tracked deletions remove the old Trellis context injection/runtime path separately from command and skill definitions.

Validation gates:

- Confirm retained OpenSpec commands and skills do not reference deleted Trellis runtime modules.

### Commit 7: Retire Trellis OpenCode skills

Proposed message: `Retire Trellis OpenCode skills`

Future staging scope:

- `.opencode/skills/trellis-before-dev/`
- `.opencode/skills/trellis-brainstorm/`
- `.opencode/skills/trellis-break-loop/`
- `.opencode/skills/trellis-check/`
- `.opencode/skills/trellis-meta/`
- `.opencode/skills/trellis-spec-bootstarp/`
- `.opencode/skills/trellis-update-spec/`

Justification: these tracked deletions remove a large obsolete Trellis skill tree and should stay separate for reviewability.

Validation gates:

- Confirm replacement OpenSpec skills exist in `.opencode/skills/openspec-*`.
- Confirm root `AGENTS.md` marks OpenSpec as active and Trellis as legacy context.

### Commit 8: Preserve or resolve Trellis task history

Proposed message: `Preserve Trellis task history`

Future staging scope requiring human decision:

- `.trellis/tasks/06-01-save-elaina-player-architecture-plan/`
- `.trellis/tasks/06-01-bootstrap-elaina-implementation/`
- `.trellis/tasks/06-01-opencode-trellis-omo-routing/`

Justification: these files contain task/session history and some useful decisions, but durable material has already been extracted into docs; raw task files require an explicit preserve/local/remove decision.

Required decision before staging:

- Commit as historical context.
- Leave local/untracked after docs extraction.
- Remove or ignore selected task logs in a separate approved cleanup change.

Validation gates:

- Review for personal/session-only details before any commit.
- Do not include `.trellis/workspace/` unless separately approved.

### Commit 9: Update Elaina architecture plan

Proposed message: `Update Elaina architecture plan`

Future staging scope:

- `docs/elaina-architecture-plan.md`

Justification: the architecture plan is the durable product roadmap and should remain independently reviewable from workflow migration, source contracts, and Trellis task history.

Validation gates:

- Confirm edits preserve the 8-layer isolation rules.
- Confirm UI still does not depend directly on MPV/VLC/Bangumi/Dandanplay/libtorrent/yuc.wiki.
- Confirm online source parsing remains outside the core playback prerequisite path.

## Blockers Before Actual Commit Execution

- Archive `refresh-baseline-staging-plan` before including its artifacts in any baseline commit.
- Re-run `openspec validate --all`, `dart analyze`, project checker scripts, and Markdown LSP diagnostics immediately before approved staging.
- Decide whether raw `.trellis/tasks/` history should be preserved, left local, or cleaned after extraction.
- Use dry-run pathspec staging for every group; never use blanket staging on this dirty tree.
