## Why

Celesteria has completed and archived the Step 1-30 contract bootstrap, so the workspace needs a stable repository baseline before further implementation work. Trellis is no longer the active workflow authority, but `.trellis/` remnants still exist and the repository lacks root hygiene such as `.gitignore`, so closeout must preserve useful history while shifting the project to OpenSpec plus git as the durable baseline.

## What Changes

- Establish a final repository baseline after the Phase 0-6 OpenSpec archive sequence.
- Verify the current git state instead of blindly running `git init`; initialize only if `.git/` is absent.
- Add repository hygiene contracts for `.gitignore`, generated/cache exclusions, and preservation of OpenSpec specs, archives, docs, and agent instructions.
- Define Trellis closeout behavior: preserve useful Trellis history or migration notes, remove Trellis from the active workflow, and update docs that still tell future agents to route through Trellis.
- Define validation gates before any first baseline commit is attempted.
- Keep commit creation as an explicit operator action; this change may prepare commit readiness but must not create a commit without a separate explicit request.

## Capabilities

### New Capabilities
- `repository-baseline`: Defines repository initialization, hygiene, Trellis closeout, validation, and commit-readiness requirements for the post-bootstrap Celesteria workspace.

### Modified Capabilities

None.

## Impact

- Affects root project metadata such as `.gitignore`, `README.md`, `AGENTS.md`, OpenSpec workflow notes, and any remaining Trellis references.
- Preserves `openspec/`, `docs/`, `lib/`, `tools/`, architecture decisions, synced specs, and archived changes as source-of-truth project history.
- Does not change product-layer Dart contracts, playback/provider/network behavior, or OpenSpec capability requirements from the archived Phase 0-6 bootstrap.
- Does not perform destructive cleanup of `.trellis/`, `.agents/`, `.codex/`, `.gemini/`, or `.sisyphus/` without an inventory and preservation decision.
