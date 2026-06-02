## Context

Celesteria now has an OpenSpec-first repository baseline, a root `.git/` on `main`, and archived Phase 0-6 contract changes. Direct checks showed the latest commit is `9e5d657 Initial Celesteria architecture plan`, while `git status --short` is dirty with many deleted Trellis OpenCode files, new OpenSpec/Dart/library/tooling files, modified docs, and `.trellis/` remnants.

The current request is to review `git status`, not to clean it. Therefore the design must preserve the dirty tree, avoid staging, and turn the status into a durable review artifact that can guide a later `/opsx-apply` or explicit commit request.

## Goals / Non-Goals

**Goals:**
- Use read-only git commands to capture dirty-tree state and classify every visible entry.
- Separate workflow/bootstrap changes from product contracts and possible user/preexisting edits.
- Identify entries that must not be staged until explicitly triaged.
- Produce an ordered, atomic future staging/commit plan.
- Keep the work compatible with PowerShell 5.1 and the repository's `safe.directory` requirement.

**Non-Goals:**
- Staging files with `git add`, `git add -A`, `git add .`, `git rm`, or interactive staging.
- Creating commits, configuring remotes, pushing, publishing, or rewriting history.
- Deleting Trellis remnants or generated files during the review proposal.
- Reworking product architecture or changing Dart source behavior.
- Treating Trellis as active workflow authority again.

## Decisions

### 1. Status review is read-only by contract

The implementation will only run inspection commands such as `git status --short --branch`, `git status --porcelain=v1 -uall`, `git diff --name-status`, `git diff --stat`, and `git ls-files --others --exclude-standard`. Every git command must preserve the index and working tree.

**Alternative considered:** stage obvious baseline files immediately. Rejected because the current dirty tree mixes deletions, generated artifacts, and migration output that need classification before staging.

### 2. Classification comes before commit planning

Dirty entries will be grouped into five buckets: OpenSpec/repository baseline additions, Dart/lib/tools baseline additions, OpenCode/OpenSpec migration and Trellis command deletions, `.trellis/` legacy remnants, and possible user/preexisting edits. A file may not enter a commit group until it has a classification and a rationale.

**Alternative considered:** group only by Git status code. Rejected because `D`, `M`, and `??` do not explain whether a file belongs to workflow migration, product contracts, generated output, or personal state.

### 3. Do-not-stage entries are first-class output

The review will explicitly list files and patterns that must remain unstaged unless separately approved: credentials, `.env*`, IDE/user state, caches, build output, logs, generated artifacts, local session state, unresolved Trellis task remnants, and unrelated experiments.

**Alternative considered:** rely on `.gitignore` alone. Rejected because `.gitignore` cannot classify tracked deletions, modified tracked files, or intentional legacy remnants.

### 4. Commit plan is advisory until explicit approval

The output may recommend atomic future commit groups, but it must stop before staging or committing. Commit order should place repository/workflow baseline before dependent product or cleanup groups and keep possible user edits isolated.

**Alternative considered:** produce one giant baseline commit plan. Rejected because mixed baseline, migration, and user edits would be hard to review, revert, or bisect.

## Review Command Set

Use PowerShell-safe commands and keep `GIT_MASTER=1` for git operations:

```powershell
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/pkpk' status --short --branch
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/pkpk' status --porcelain=v1 -uall
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/pkpk' diff --name-status
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/pkpk' diff --stat
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/pkpk' ls-files --others --exclude-standard
```

## Classification Buckets

1. **OpenSpec/repository baseline:** `openspec/`, `.gitignore`, `README.md`, `AGENTS.md`, root manifests, and archived/spec-synced workflow artifacts.
2. **Dart/lib/tools baseline:** `analysis_options.yaml`, `pubspec.yaml`, `lib/`, `tools/`, and validation scripts created by Phase 0-6 contract work.
3. **OpenCode/OpenSpec migration and Trellis command deletions:** `.opencode/` deletions or replacements, OpenSpec skills/commands, and retired Trellis-specific OpenCode agents/hooks.
4. **Trellis legacy remnants:** `.trellis/tasks/`, `.trellis/workspace/`, Trellis specs, journals, scripts, and migration breadcrumbs that need preservation or deletion decisions.
5. **Possible user/preexisting edits:** modified tracked files outside clear baseline paths, small non-generated deltas, local notes, and any entry whose purpose is not proven by the migration record.

## Risks / Trade-offs

- **[Risk] Blanket staging pollutes the baseline** -> **Mitigation:** prohibit `git add .`, `git add -A`, `git commit -a`, and `git rm` during review.
- **[Risk] User work is hidden in baseline migration** -> **Mitigation:** isolate possible user/preexisting edits and require explicit classification before staging.
- **[Risk] Useful Trellis history is lost** -> **Mitigation:** keep Trellis remnants in a separate bucket until preservation policy is decided.
- **[Risk] Generated artifacts enter source control** -> **Mitigation:** compare untracked files against `.gitignore` and the do-not-stage list before any commit plan is accepted.
- **[Risk] PowerShell command syntax breaks the review** -> **Mitigation:** use semicolon-separated PowerShell commands and avoid `&&`.

## Open Questions

- Which `.trellis/tasks/` and `.trellis/workspace/` files should be preserved in git versus ignored as local session history?
- Should retired `.opencode/` Trellis files be committed as deletions in the first baseline commit or separated into a workflow cleanup commit?
- If the user later requests a commit, what exact message style should be used for each atomic group?
