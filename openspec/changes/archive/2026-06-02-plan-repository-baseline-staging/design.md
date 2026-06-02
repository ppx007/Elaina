## Context

The archived `review-git-status-baseline` report records a dirty tree on `main` with no staged diff, 48 tracked unstaged files, 136 insertions, 5,187 deletions, and a large untracked OpenSpec/Dart baseline. It classifies the tree into five buckets: OpenSpec/repository baseline, Dart/lib/tools baseline, OpenCode/OpenSpec migration and Trellis command deletions, Trellis legacy remnants, and possible user/preexisting edits.

The repository also now has a synced `git-status-review` spec requiring read-only review, do-not-stage boundaries, and advisory atomic commit planning before any staging or commit creation. This change builds the next layer: a planning artifact that can later be applied into a precise staging plan.

## Goals / Non-Goals

**Goals:**
- Produce a file-scoped staging plan from the archived status review.
- Detect commit-message style from repository history before proposing messages.
- Define branch context and rewrite safety before any future git operation.
- Split the dirty tree into atomic groups with one clear purpose per group.
- Require a justification sentence for every group with three or more files.
- Define validation gates for a future implementation step.

**Non-Goals:**
- Running `git add`, `git add -p`, `git rm`, `git commit`, `git reset`, `git checkout`, `git clean`, `git push`, or remote configuration.
- Deleting Trellis remnants, task history, or old OpenCode files.
- Rewriting architecture docs or Dart contracts beyond the staging plan artifacts.
- Treating the advisory plan as permission to commit.

## Decisions

### 1. Planning output is a standalone artifact

The apply phase should create a `staging-plan.md` artifact in this change that contains the exact groups, file scopes, proposed messages, justification, dependency order, validation commands, and unresolved decisions. This keeps the plan reviewable before any Git mutation.

**Alternative considered:** encode the plan only in `tasks.md`. Rejected because the tree is large enough that the plan needs tables, rationale, and review notes beyond a checklist.

### 2. Use the archived review as the source of truth

The plan must start from `openspec/changes/archive/2026-06-02-review-git-status-baseline/status-review.md` and then re-check current status for drift. Divergence between current status and the archived report must be called out before staging groups are finalized.

**Alternative considered:** reclassify from scratch. Rejected because the archived review already captured the intended grouping and should remain auditable.

### 3. Split into commit families before exact commits

The first planning pass will use five commit families from the status review, then subdivide if a family violates atomicity or file-count rules.

Initial families:
- Repository/OpenSpec workflow baseline.
- Dart contract and tooling baseline.
- Retire Trellis OpenCode integration.
- Trellis legacy preservation decision.
- Architecture/user-review edits.

**Alternative considered:** one baseline commit. Rejected because the dirty tree mixes workflow authority, product contracts, deletions, legacy task history, and possible user edits.

### 4. Git mutations remain separately authorized

The output may contain future commands for review, dry-run, and selective staging, but they remain instructions for a later explicitly approved step. The apply phase for this change must not execute staging or commit commands.

**Alternative considered:** apply the staging plan immediately. Rejected because the user requested planning and the repository baseline specs require explicit approval before commit actions.

## Commit Planning Rules

- Detect commit style from recent history before writing final messages.
- Current known history is sparse; if only `9e5d657 Initial Celesteria architecture plan` is available, use plain English sentence-case messages unless new evidence appears.
- Use at least one group per independent concern and split large groups until each commit can be reviewed independently.
- Pair validation scripts and the contracts they validate when they are inseparable; otherwise split by layer or module.
- Keep `.trellis/tasks/` and `.trellis/workspace/` separate until preservation policy is explicit.
- Never include generated caches, secrets, personal state, logs, or unrelated experiments.

## Proposed Dependency Order

1. Repository/OpenSpec workflow baseline.
2. Dart contract and tooling baseline.
3. Retire Trellis OpenCode integration.
4. Trellis legacy preservation decision.
5. Architecture/user-review edits.

## Risks / Trade-offs

- **[Risk] Tree drift invalidates the archived grouping** -> **Mitigation:** re-run read-only status and record drift before finalizing `staging-plan.md`.
- **[Risk] Commit groups are too broad** -> **Mitigation:** require file-count checks and a justification for every group with three or more files.
- **[Risk] Trellis history is committed or deleted incorrectly** -> **Mitigation:** keep Trellis task/workspace material in its own preservation group.
- **[Risk] Planning becomes execution by accident** -> **Mitigation:** prohibit staging, committing, deletion, remote configuration, push, and history rewrite in this change.
- **[Risk] Commit message style is guessed** -> **Mitigation:** require style detection from `git log` before final messages are accepted.

## Open Questions

- Should `.trellis/tasks/` be committed as historical project context, moved into docs, or ignored as session state?
- Should the retired `.opencode/` Trellis deletions be committed together or split by agents, commands, libs, plugins, and skills?
- Should Phase 0-6 Dart contracts and docs be one baseline family or split by archived phase?
- What exact commit messages should be used if the user later approves staging and commits?
