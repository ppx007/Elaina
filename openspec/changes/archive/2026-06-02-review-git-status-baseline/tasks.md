## 1. Read-only status capture

- [x] 1.1 Confirm OpenSpec has no active changes before reviewing git status.
- [x] 1.2 Run PowerShell-safe read-only git status commands with `GIT_MASTER=1` and `safe.directory` set for `D:/CodeWork/pkpk`.
- [x] 1.3 Capture short status, porcelain status, name-status diff, diff stat, and untracked file list without staging or modifying files.

## 2. Dirty-tree classification

- [x] 2.1 Classify OpenSpec/repository baseline files such as `openspec/`, `.gitignore`, `README.md`, `AGENTS.md`, and root manifests.
- [x] 2.2 Classify Dart/lib/tools baseline files such as `analysis_options.yaml`, `pubspec.yaml`, `lib/`, and `tools/`.
- [x] 2.3 Classify OpenCode/OpenSpec migration files and retired Trellis OpenCode deletions under `.opencode/` or related agent-skill directories.
- [x] 2.4 Classify `.trellis/` legacy remnants separately from OpenSpec source-of-truth files.
- [x] 2.5 Flag possible user/preexisting edits that need explicit review before staging.

## 3. Staging boundaries and commit plan

- [x] 3.1 Produce a do-not-stage list for secrets, `.env*`, IDE/user state, caches, logs, build output, generated artifacts, unresolved Trellis remnants, and unrelated experiments.
- [x] 3.2 Produce a future atomic commit plan with one logical purpose per group and explicit dependencies between groups.
- [x] 3.3 Prohibit `git add .`, `git add -A`, `git commit -a`, `git rm`, deletion, remote configuration, push, publish, and commit creation during this review.

## 4. Validation and handoff

- [x] 4.1 Run `openspec validate review-git-status-baseline` after proposal artifacts are created.
- [x] 4.2 Confirm `openspec instructions apply --change "review-git-status-baseline" --json` is available for the next implementation step.
- [x] 4.3 Report that the change is ready for `/opsx-apply review-git-status-baseline` and that the working tree has not been staged or committed.
