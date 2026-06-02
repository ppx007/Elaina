## 1. Re-check baseline inputs

- [x] 1.1 Confirm there are no active OpenSpec changes other than `plan-repository-baseline-staging`.
- [x] 1.2 Read the archived `review-git-status-baseline/status-review.md` and synced `git-status-review` spec.
- [x] 1.3 Run read-only git status, diff stat, staged diff stat, and log/style detection commands with `GIT_MASTER=1`.
- [x] 1.4 Record any drift between current status and the archived review before finalizing groups.

## 2. Build staging-plan.md

- [x] 2.1 Create `staging-plan.md` in this change directory.
- [x] 2.2 Define repository/OpenSpec workflow baseline group with exact files, rationale, and validation gates.
- [x] 2.3 Define Dart contract and tooling baseline group with exact files, rationale, and validation gates.
- [x] 2.4 Define retired Trellis OpenCode integration group with exact tracked deletions and preservation notes.
- [x] 2.5 Define Trellis legacy preservation group and mark unresolved preservation decisions.
- [x] 2.6 Define architecture/user-review edits group and mark files that require human diff review.

## 3. Enforce atomicity rules

- [x] 3.1 Calculate changed-file counts per group and split any group that is too broad to review independently.
- [x] 3.2 Add one justification sentence for every proposed commit group with three or more files.
- [x] 3.3 Add proposed commit messages that match detected repository style.
- [x] 3.4 Mark all staging commands as future/manual-only and prohibit executing them in this change.

## 4. Validation and readiness

- [x] 4.1 Include validation commands for a future approved staging step, including `git diff --staged --stat`, `openspec validate --all`, `dart analyze`, and project checker scripts.
- [x] 4.2 Ensure `staging-plan.md` preserves do-not-stage boundaries for secrets, generated files, local state, unresolved Trellis remnants, and unclear entries.
- [x] 4.3 Run `openspec validate plan-repository-baseline-staging` after artifacts are created.
- [x] 4.4 Confirm apply instructions are available and report that the change is ready for `/opsx-apply plan-repository-baseline-staging`.
