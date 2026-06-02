## Git Status Review

Date: 2026-06-02
Branch: `main`
Mode: read-only review only

## Commands Run

All git commands were run with `GIT_MASTER=1` and a per-command `safe.directory` override for `D:/CodeWork/pkpk`.

```powershell
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/pkpk' status --short --branch
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/pkpk' diff --name-status
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/pkpk' ls-files --others --exclude-standard
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/pkpk' status --porcelain=v1 -uall
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/pkpk' diff --stat
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/pkpk' diff --cached --stat
```

`git diff --cached --stat` returned no output, so no staged snapshot was present during this review.

## Summary

- Active OpenSpec change: `review-git-status-baseline`
- OpenSpec task state before apply: 0/14 complete
- Tracked unstaged diff: 48 files changed, 136 insertions, 5,187 deletions
- Staged diff: none
- Branch: `main`
- No staging, deletion, commit, remote configuration, push, publish, reset, checkout, or cleanup command was run.

## Classification

### 1. OpenSpec / Repository Baseline

These entries are repository workflow and OpenSpec source-of-truth baseline candidates:

- `.gitignore`
- `README.md`
- `AGENTS.md`
- `openspec/`
- `.opencode/commands/opsx-apply.md`
- `.opencode/commands/opsx-archive.md`
- `.opencode/commands/opsx-explore.md`
- `.opencode/commands/opsx-propose.md`
- `.opencode/skills/openspec-apply-change/`
- `.opencode/skills/openspec-archive-change/`
- `.opencode/skills/openspec-explore/`
- `.opencode/skills/openspec-propose/`

Rationale: these files define the active OpenSpec workflow authority, archived changes, synced specs, and repository baseline documentation.

### 2. Dart / Lib / Tools Baseline

These entries are contract bootstrap and validation baseline candidates:

- `analysis_options.yaml`
- `pubspec.yaml`
- `lib/`
- `tools/`
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

Rationale: these files were created by the Phase 0-6 contract bootstrap and checker sequence and should be reviewed as source baseline, not as generated output.

### 3. OpenCode / OpenSpec Migration and Trellis Command Deletions

These tracked deletions are retired Trellis-specific OpenCode files:

- `.opencode/agents/trellis-check.md`
- `.opencode/agents/trellis-implement.md`
- `.opencode/agents/trellis-research.md`
- `.opencode/commands/trellis/continue.md`
- `.opencode/commands/trellis/finish-work.md`
- `.opencode/lib/session-utils.js`
- `.opencode/lib/trellis-context.js`
- `.opencode/plugins/inject-subagent-context.js`
- `.opencode/plugins/inject-workflow-state.js`
- `.opencode/plugins/session-start.js`
- `.opencode/skills/trellis-before-dev/SKILL.md`
- `.opencode/skills/trellis-brainstorm/SKILL.md`
- `.opencode/skills/trellis-break-loop/SKILL.md`
- `.opencode/skills/trellis-check/SKILL.md`
- `.opencode/skills/trellis-meta/`
- `.opencode/skills/trellis-spec-bootstarp/`
- `.opencode/skills/trellis-update-spec/SKILL.md`

Rationale: these deletions align with the repository decision that OpenSpec is now active workflow authority and Trellis is legacy context. They should still be reviewed carefully because they remove a large amount of agent/runtime support code.

### 4. Trellis Legacy Remnants

These entries should not be blindly staged as baseline without preservation policy review:

- Modified tracked files under `.trellis/tasks/06-01-save-elaina-player-architecture-plan/`
- New `.trellis/tasks/06-01-bootstrap-celesteria-implementation/`
- New `.trellis/tasks/06-01-opencode-trellis-omo-routing/`

Rationale: `.trellis/` is retained as legacy context, and task/workspace material may be session history rather than durable project source. These entries are candidates for a separate preservation/ignore decision.

### 5. Possible User / Preexisting Edits

These entries require explicit review before staging because they are tracked edits outside a purely generated baseline path:

- `docs/celesteria-architecture-plan.md`
- `AGENTS.md`
- `.trellis/tasks/06-01-save-elaina-player-architecture-plan/prd.md`
- `.trellis/tasks/06-01-save-elaina-player-architecture-plan/task.json`
- `.trellis/tasks/06-01-save-elaina-player-architecture-plan/check.jsonl`
- `.trellis/tasks/06-01-save-elaina-player-architecture-plan/implement.jsonl`

Rationale: these files may include intentional architecture or workflow changes, but they also overlap with legacy task/session records. They should be reviewed by diff before staging.

## Do-Not-Stage Boundary

Do not stage the following during this review:

- `.env*`, credentials, tokens, private keys, cookies, or local auth material.
- IDE/user state, OS files, logs, temp files, caches, build output, generated binaries, and package caches.
- Unresolved `.trellis/tasks/` or `.trellis/workspace/` session history until the user decides whether to preserve, migrate, or ignore it.
- Unrelated experiments or local notes not tied to the OpenSpec baseline.
- Any file whose purpose cannot be mapped to one of the classification buckets above.

## Advisory Atomic Commit Plan

This is advisory only. It is not permission to stage or commit.

1. **Repository/OpenSpec workflow baseline**
   - Files: `.gitignore`, `README.md`, `AGENTS.md`, `openspec/`, OpenSpec `.opencode/commands/opsx-*`, OpenSpec `.opencode/skills/openspec-*`.
   - Rationale: establishes the active workflow authority and durable repository source-of-truth.

2. **Dart contract and tooling baseline**
   - Files: `analysis_options.yaml`, `pubspec.yaml`, `lib/`, `tools/`, Phase 0-6 docs.
   - Rationale: adds source and validation contracts from the archived bootstrap sequence.

3. **Retire Trellis OpenCode integration**
   - Files: tracked deletions under `.opencode/agents/trellis-*`, `.opencode/commands/trellis/`, `.opencode/lib/trellis-context.js`, `.opencode/plugins/`, and `.opencode/skills/trellis-*`.
   - Rationale: removes obsolete active Trellis routing from OpenCode after OpenSpec became authority.

4. **Trellis legacy preservation decision**
   - Files: `.trellis/tasks/06-01-save-elaina-player-architecture-plan/`, `.trellis/tasks/06-01-bootstrap-celesteria-implementation/`, `.trellis/tasks/06-01-opencode-trellis-omo-routing/`.
   - Rationale: should be split until user decides whether task/session history belongs in the repository.

5. **Architecture/user-review edits**
   - Files: `docs/celesteria-architecture-plan.md` and any remaining tracked edits whose purpose is not proven by baseline work.
   - Rationale: keeps intentional architecture changes reviewable apart from workflow migration.

## Residual Risks

- The tracked deletion set is large and should not be committed without reviewing whether any Trellis meta guidance still needs preservation.
- `.trellis/tasks/` contains session-like history and should remain separate from source baseline until the preservation decision is explicit.
- Line-ending warnings appeared for some tracked modified files; they are not a staging blocker but should be expected if Git later touches those paths.
- The untracked `openspec/` tree is large because prior archived changes and synced specs are not yet tracked in the repository.
