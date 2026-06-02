## 1. Read-only status refresh

- [x] 1.1 Run `openspec list --json` and record active changes.
- [x] 1.2 Run read-only git status, porcelain, tracked diff, staged diff, untracked file, branch, and recent log checks with `GIT_MASTER=1`.
- [x] 1.3 Confirm no staging, deletion, commit, reset, remote configuration, push, or publish command is run.

## 2. Drift analysis

- [x] 2.1 Compare current status against `openspec/changes/archive/2026-06-02-review-git-status-baseline/status-review.md`.
- [x] 2.2 Compare current status against `openspec/changes/archive/2026-06-02-plan-repository-baseline-staging/staging-plan.md`.
- [x] 2.3 Record resolved drift, including `.opencode/tmp-*` no longer appearing in nonignored untracked output.
- [x] 2.4 Record new drift, including Trellis extraction docs, Markdown LSP OpenSpec artifacts/specs, and the active `refresh-baseline-staging-plan` change.

## 3. Updated staging-plan artifact

- [x] 3.1 Create `openspec/changes/refresh-baseline-staging-plan/refreshed-staging-plan.md` with current observations, classification, commit groups, blockers, and validation gates.
- [x] 3.2 Keep OpenSpec workflow baseline, Dart contract baseline, phase docs, Trellis OpenCode retirement, Trellis history, and architecture plan review as separate concerns.
- [x] 3.3 Add or update groups for Trellis extraction docs and Markdown LSP OpenSpec artifacts where appropriate.
- [x] 3.4 Explicitly exclude the active change directory until after archive.
- [x] 3.5 Record future staging safeguards: no `git add -A`, no `git add .`, no `git commit -a`, and require `git add -n <pathspecs>` plus staged-diff review per group.

## 4. Validation and handoff

- [x] 4.1 Validate the change with `openspec validate refresh-baseline-staging-plan`.
- [x] 4.2 Confirm apply instructions report all tasks complete after implementation.
- [x] 4.3 Report that the refreshed plan remains advisory and requires explicit user approval before any staging or commit.
