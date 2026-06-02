## Why

The repository baseline staging plan identifies `.trellis/tasks/` and `.trellis/workspace/` as unresolved legacy context, while `.opencode/tmp-check.ps1`, `.opencode/tmp-cleanup.cmd`, and `.opencode/tmp-cleanup.js` are known local cleanup artifacts that must not enter the baseline. Valuable Trellis knowledge is still buried in dot-directories and session traces, while temporary agent files remain mixed into `git status`.

This change proposes a controlled extraction and confirmation pass: promote durable Trellis knowledge into `docs/`, classify task/workspace remnants, and confirm local garbage before any baseline staging or deletion occurs.

## What Changes

- Inventory `.trellis/tasks/`, `.trellis/workspace/`, `.trellis/spec/guides/`, `.trellis/workflow.md`, relevant docs, and known `.opencode/tmp-*` files.
- Extract durable architecture/process/engineering guidance from Trellis into stable docs targets.
- Create clear docs targets for Trellis thinking guides, workflow process notes, maintenance notes, and extracted historical decisions.
- Confirm `.opencode/tmp-check.ps1`, `.opencode/tmp-cleanup.cmd`, and `.opencode/tmp-cleanup.js` as removable local garbage after content review.
- Define safeguards that prevent deletion or loss of OpenSpec specs, Trellis scripts, active task context, useful architecture decisions, or user-authored content.

## Capabilities

### New Capabilities
- `trellis-context-extraction`: Defines how valuable Trellis context is promoted into docs and how local garbage is confirmed before cleanup.

### Modified Capabilities

None.

## Impact

- Affects documentation organization, Trellis legacy handling, and future baseline staging decisions.
- Does not change Dart runtime contracts, app architecture, OpenSpec synced product specs, or git history.
- Does not delete files during proposal; deletion/ignore actions are deferred to `/opsx-apply` with explicit inventory evidence.
- Helps unblock the `Preserve or resolve Trellis task history` and temp-file blockers from the archived staging plan.
