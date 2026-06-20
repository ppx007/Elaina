## Why

The repository baseline has been finalized and archived, but the working tree is still intentionally dirty with a large mix of OpenSpec bootstrap files, Dart contract scaffolding, workflow migration files, Trellis remnants, and possible user edits. Reviewing that status casually would make it too easy to hide unrelated work inside one baseline commit or accidentally stage files that should remain local.

This change creates a read-only git status review contract before any staging, deletion, or commit work. The goal is to classify the dirty tree into reviewable groups, identify files that must not be staged, and prepare a future atomic staging plan without changing the index or repository history.

## What Changes

- Define a read-only `git status` review flow for the post-bootstrap Elaina workspace.
- Require stable, parseable status and diff commands before any staging decisions.
- Classify dirty entries into OpenSpec/repository baseline, Dart/lib/tooling baseline, OpenCode/OpenSpec migration, Trellis legacy remnants, and possible user/preexisting edits.
- Produce an explicit do-not-stage list for credentials, generated files, personal state, local caches, unrelated experiments, and unresolved Trellis remnants.
- Produce a future atomic commit plan while stopping before `git add`, `git rm`, `git commit`, remote configuration, push, or deletion.

## Capabilities

### New Capabilities
- `git-status-review`: Defines read-only dirty-tree review, classification, staging boundaries, and commit-plan requirements before repository baseline staging.

### Modified Capabilities

None.

## Impact

- Affects repository closeout workflow and future staging/commit preparation.
- Does not change Dart runtime contracts, OpenSpec synced product specs, playback/provider/network boundaries, or app behavior.
- Does not stage, delete, commit, push, publish, or configure remotes.
- Supports the existing `repository-baseline` requirement that commits require explicit user approval.
