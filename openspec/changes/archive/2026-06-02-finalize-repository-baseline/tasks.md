## 1. Repository state inventory

- [x] 1.1 Confirm OpenSpec has no active changes and all synced specs validate.
- [x] 1.2 Verify whether `.git/` exists and record the current git branch/status without staging files.
- [x] 1.3 Inventory root project files and directories that must be preserved in the baseline.
- [x] 1.4 Confirm `.gitignore`, `README.md`, and repository hygiene files are present or missing.

## 2. Git hygiene baseline

- [x] 2.1 Create or update root `.gitignore` for Dart, Flutter, Python, IDE, OS, log, build, cache, and temporary artifacts.
- [x] 2.2 Ensure `.gitignore` preserves OpenSpec specs, archived changes, docs, lib contracts, tools, manifests, and agent instructions by default.
- [x] 2.3 Add a repository baseline note or README update describing the OpenSpec-first workflow.
- [x] 2.4 If `.git/` is absent, initialize the repository; if `.git/` exists, do not reinitialize it.

## 3. Trellis closeout

- [x] 3.1 Inventory `.trellis/`, `.agents/skills/trellis-*`, and docs that still refer to Trellis as active workflow.
- [x] 3.2 Preserve or migrate useful Trellis guidance into OpenSpec-facing docs before changing ignore/delete behavior.
- [x] 3.3 Update project instructions so Trellis is treated as legacy context and OpenSpec is the active workflow authority.
- [x] 3.4 Avoid deleting Trellis history or personal journals unless the user separately approves the deletion policy.

## 4. Validation and commit readiness

- [x] 4.1 Run `openspec validate --all` after repository baseline changes.
- [x] 4.2 Run `dart analyze` after repository baseline changes.
- [x] 4.3 Run available project checker scripts, including the latest automation extension checker.
- [x] 4.4 Report `git status --short` and a selective staging plan without staging or committing by default.
- [x] 4.5 Stop before creating any git commit unless the user explicitly requests commit creation.
