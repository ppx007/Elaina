## 1. Inventory and classification

- [x] 1.1 Inventory `.trellis/tasks/`, `.trellis/tasks/archive/`, `.trellis/workspace/`, `.trellis/spec/guides/`, `.trellis/workflow.md`, and `.opencode/tmp-*` files.
- [x] 1.2 Create a classification table with `extract-to-docs`, `keep-legacy`, `confirm-garbage`, and `blocked-review` categories.
- [x] 1.3 Read each active task PRD and identify durable decisions versus session-only execution traces.
- [x] 1.4 Read `.opencode/tmp-check.ps1`, `.opencode/tmp-cleanup.cmd`, and `.opencode/tmp-cleanup.js` and confirm they contain only generated cleanup/check logic.

## 2. Extract durable Trellis knowledge into docs

- [x] 2.1 Create `docs/process/trellis-legacy-extraction.md` with inventory, classification, and traceability back to source paths.
- [x] 2.2 Create `docs/process/repository-baseline-cleanup.md` documenting temp-file confirmation and future baseline staging implications.
- [x] 2.3 Create `docs/guides/cross-layer-thinking.md` from `.trellis/spec/guides/cross-layer-thinking-guide.md` without Trellis-specific command-template noise unless still relevant.
- [x] 2.4 Create `docs/guides/code-reuse-thinking.md` from `.trellis/spec/guides/code-reuse-thinking-guide.md`.
- [x] 2.5 Create `docs/decisions/phase0-implementation-scope.md` summarizing durable decisions from the architecture/save/bootstrap PRDs.

## 3. Confirm garbage and safeguards

- [x] 3.1 Mark `.opencode/tmp-check.ps1`, `.opencode/tmp-cleanup.cmd`, and `.opencode/tmp-cleanup.js` as confirmed garbage after content audit.
- [x] 3.2 Define cleanup commands as future/manual-only until the docs extraction is reviewed.
- [x] 3.3 Add or confirm ignore coverage for `.opencode/tmp-*` if needed.
- [x] 3.4 Ensure `.trellis/scripts/`, `.trellis/spec/guides/`, OpenSpec artifacts, and root project docs are not classified as garbage.

## 4. Validation and handoff

- [x] 4.1 Run `openspec validate trellis-extract-valuable-to-docs-confirm-garbage` after proposal artifacts are created.
- [x] 4.2 Confirm apply instructions are available for the change.
- [x] 4.3 Report that the change is ready for `/opsx-apply trellis-extract-valuable-to-docs-confirm-garbage`.
