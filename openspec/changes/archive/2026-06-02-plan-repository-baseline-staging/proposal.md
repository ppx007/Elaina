## Why

The `review-git-status-baseline` change has been archived and synced, leaving a classified dirty tree but no approved staging or commit execution plan. The workspace still contains a large mix of OpenSpec baseline artifacts, Dart contract scaffolding, OpenCode/OpenSpec migration files, retired Trellis OpenCode deletions, Trellis task remnants, and possible user/preexisting edits.

The next step is to convert the read-only status review into a concrete, reviewable repository baseline staging plan. This change stays planning-only: it defines the groups, ordering, message style checks, validation gates, and unresolved decisions that must be settled before any future staging or commit request.

## What Changes

- Create a repository baseline staging plan derived from `openspec/changes/archive/2026-06-02-review-git-status-baseline/status-review.md`.
- Define atomic staging/commit groups for OpenSpec workflow baseline, Dart/lib/tools baseline, Trellis OpenCode retirement, Trellis legacy preservation, and architecture/user-review edits.
- Require git style detection, branch context, dependency ordering, minimum commit count checks, and per-group justification before staging can be recommended.
- Preserve the do-not-stage boundaries from `git-status-review`, including secrets, generated files, local session state, unresolved Trellis remnants, and unclear entries.
- Stop at a human-reviewable staging plan; do not stage, commit, delete, push, configure remotes, or rewrite history.

## Capabilities

### New Capabilities
- `repository-baseline-staging-plan`: Defines planning requirements for turning the classified dirty tree into reviewable, atomic staging groups without performing git mutations.

### Modified Capabilities

None.

## Impact

- Affects repository closeout planning and future baseline commit readiness.
- Consumes the archived `git-status-review` results and complements the existing `repository-baseline` spec.
- Does not change Dart runtime contracts, synced product specs, app behavior, or architecture boundaries.
- Does not create a commit or authorize staging; future execution still requires explicit user approval.
