## Why

The previous repository baseline staging plan was created before Trellis extraction and Markdown LSP cleanup were completed. The working tree now includes additional docs, synced OpenSpec specs, archived changes, and ignored temp-file drift, so the baseline staging plan needs a fresh read-only status review before any future staging or commit request.

## What Changes

- Re-run read-only git status, diff, staged-diff, untracked-file, branch, and recent-history checks with `GIT_MASTER=1`.
- Compare current dirty-tree output against the archived `review-git-status-baseline` and `plan-repository-baseline-staging` artifacts.
- Update the advisory staging plan to account for:
  - completed Trellis context extraction docs under `docs/process/`, `docs/guides/`, and `docs/decisions/`;
  - archived/synced `trellis-context-extraction` and `markdown-lsp-configuration` OpenSpec specs;
  - `.opencode/tmp-*` no longer appearing in nonignored untracked output because root `.gitignore` ignores them;
  - the active `refresh-baseline-staging-plan` change itself, which must not be staged until archived.
- Preserve the rule that this change is planning-only: no staging, commits, deletion, reset, remote configuration, or push.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `repository-baseline-staging-plan`: Adds a refresh pass that consumes the latest read-only git state after Trellis extraction and Markdown LSP cleanup.

## Impact

- Affects OpenSpec planning artifacts and future baseline staging guidance only.
- Does not mutate the git index, create commits, delete files, configure remotes, push, or publish.
- Does not change Elaina runtime contracts except for the delta spec that records the refreshed staging-plan requirement.
