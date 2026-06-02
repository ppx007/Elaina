## Context

The archived `plan-repository-baseline-staging` change produced an advisory eight-group baseline staging plan. Since then, two cleanup/maintenance changes completed:

- `trellis-extract-valuable-to-docs-confirm-garbage` extracted useful Trellis context into `docs/`, added `.opencode/tmp-*` ignore coverage, and synced `trellis-context-extraction`.
- `configure-markdown-lsp` configured Markdown diagnostics using `marksman server`, synced `markdown-lsp-configuration`, and archived its change.

Current read-only git checks show the repository is still on `main`, with no staged diff. The tracked unstaged diff still reports 48 files with 136 insertions and 5,187 deletions. The untracked tree is large and now includes the newly archived/synced OpenSpec material, Trellis extraction docs, and Dart/lib/tooling baseline files. `.opencode/tmp-*` no longer appears in nonignored untracked output.

## Goals / Non-Goals

**Goals:**

- Produce a refreshed planning-only staging plan during apply.
- Reclassify current dirty entries using latest status output.
- Update future commit groups and validation gates to include the Trellis extraction and Markdown LSP changes.
- Keep active OpenSpec change files out of any future staging group until archived.

**Non-Goals:**

- Staging files.
- Creating commits.
- Deleting ignored temp files or Trellis history.
- Rewriting history, rebasing `main`, configuring remotes, pushing, or publishing.
- Deciding final commit execution without explicit user approval.

## Decisions

### Keep this as planning-only

The repository is on `main` and the dirty tree mixes workflow migration, source baseline, docs, legacy Trellis history, and active OpenSpec proposal state. The safe next step is another planning artifact, not mutation.

### Update groups instead of replacing the entire strategy

The archived staging plan's broad grouping remains valid: OpenSpec workflow baseline, Dart contracts, phase docs, Trellis retirement deletions, Trellis legacy history, and architecture plan review. The refresh should update drift and add new docs/specs rather than invent an unrelated grouping model.

### Treat `.opencode/tmp-*` as resolved for staging-plan purposes

The prior blocker was that the temp files appeared in status. They are now ignored by root `.gitignore`, and cleanup docs classify them as future/manual-only deletion candidates. They remain a do-not-stage class but no longer block advisory grouping.

### Keep active change artifacts excluded

`openspec/changes/refresh-baseline-staging-plan/` is active while this proposal is being applied. It should appear as observed drift, but future staging may include it only after archive.

### Require pathspec-driven dry-run staging for future execution

Large dirty trees must be staged with explicit pathspecs or patch selection only. Future execution should use `git status --porcelain`, `git ls-files --others --exclude-standard`, `git diff --stat`, `git add -n <pathspecs>`, and `git diff --cached --stat` around each group. Blanket staging commands such as `git add -A`, `git add .`, and `git commit -a` are unsafe for this repository state because they can mix tracked deletions, untracked baseline files, ignored cleanup drift, and active OpenSpec proposal files.

## Risks / Trade-offs

- **[Risk] One giant baseline commit becomes tempting** -> **Mitigation:** preserve multi-group staging guidance and require dry-run staging per group.
- **[Risk] Active OpenSpec proposal files are staged too early** -> **Mitigation:** explicitly exclude active change directories until archive.
- **[Risk] Trellis task history is treated as either source or garbage without review** -> **Mitigation:** keep Trellis task/workspace material in a separate human-decision group.
- **[Risk] New user-level Markdown LSP config is confused with repository baseline** -> **Mitigation:** record it as user config completed outside repository staging; only OpenSpec artifacts about that work belong in repository planning.
- **[Risk] Future execution stages unrelated files from the large dirty tree** -> **Mitigation:** require explicit pathspec dry-runs and staged-diff review for each group; forbid blanket staging commands.
