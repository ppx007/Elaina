## Context

The archived repository baseline staging plan marks `.trellis/tasks/` and `.trellis/workspace/` as unresolved. Direct reads show three active task PRDs with useful historical decisions:

- `.trellis/tasks/06-01-save-elaina-player-architecture-plan/prd.md`: records Elaina naming, Phase 0 / Step 1-4 as first implementation slice, yuc.wiki as RSS `FeedSource`, and extension-point boundaries.
- `.trellis/tasks/06-01-bootstrap-elaina-implementation/prd.md`: confirms the first executable slice should implement full Phase 0 / Step 1-4 rather than player UI.
- `.trellis/tasks/06-01-opencode-trellis-omo-routing/prd.md`: records an obsolete OpenCode/Trellis-to-OMO routing plan now superseded by OpenSpec-first workflow.

Direct reads also show `.trellis/spec/guides/cross-layer-thinking-guide.md` contains reusable bug-prevention guidance and real examples. `.trellis/workspace/index.md` is mostly a generic Trellis workspace template. The `.opencode/tmp-*` files are one-off cleanup/check scripts from the earlier archive troubleshooting session and should be treated as garbage candidates after confirmation.

## Goals / Non-Goals

**Goals:**
- Inventory Trellis task, workspace, workflow, and guide content before cleanup.
- Extract durable lessons into docs with stable, human-readable paths.
- Classify remaining Trellis task/workspace content as keep-local, extract-summary, or garbage/archive candidate.
- Confirm `.opencode/tmp-*` files are generated cleanup artifacts and safe to remove in apply.
- Preserve operational Trellis scripts and OpenSpec artifacts unless explicitly classified.

**Non-Goals:**
- Deleting `.trellis/` wholesale.
- Re-enabling Trellis as the active workflow authority.
- Modifying product-layer Dart contracts.
- Staging, committing, pushing, or rewriting git history.
- Moving all task logs into docs without summarization.

## Extraction Targets

Create or update these docs targets during apply:

- `docs/process/trellis-legacy-extraction.md`: inventory, classification table, and final keep/extract/garbage decisions.
- `docs/process/repository-baseline-cleanup.md`: cleanup rationale, `.opencode/tmp-*` confirmation, and future staging implications.
- `docs/guides/cross-layer-thinking.md`: durable extraction from `.trellis/spec/guides/cross-layer-thinking-guide.md`.
- `docs/guides/code-reuse-thinking.md`: durable extraction from `.trellis/spec/guides/code-reuse-thinking-guide.md`.
- `docs/decisions/phase0-implementation-scope.md`: summarized durable decisions from the architecture-plan and bootstrap PRDs.

## Classification Rules

### Extract to docs

- Reusable architecture decisions, workflow decisions, anti-patterns, and future implementation constraints.
- Trellis thinking guides with general engineering value.
- PRD decisions that explain why Phase 0 / Step 1-4 came first.
- Decisions that affect future baseline staging or commit grouping.

### Keep as legacy/local

- Trellis scripts and runtime files needed to read historical context.
- Per-developer journals and workspace traces unless a reusable lesson is extracted.
- Task JSONL execution traces that are not useful outside their original task.

### Confirm garbage

- `.opencode/tmp-check.ps1`
- `.opencode/tmp-cleanup.cmd`
- `.opencode/tmp-cleanup.js`
- Future files matching `.opencode/tmp-*` only after content review confirms they are generated one-off cleanup/check artifacts.

## Safeguards

- Do not delete anything under `openspec/`, `docs/`, `lib/`, `tools/`, root manifests, or `.trellis/scripts/`.
- Do not delete `.trellis/spec/guides/` until docs extraction is reviewed.
- Do not delete task PRDs before their durable decisions are summarized.
- Do not treat files with `KEEP`, `DO_NOT_DELETE`, user notes, secrets, credentials, or project-specific implementation content as garbage.
- Prefer docs extraction plus ignore/removal decisions over bulk deletion.

## Risks / Trade-offs

- **[Risk] Useful Trellis history is lost** -> **Mitigation:** inventory and summarize before classifying anything as local or garbage.
- **[Risk] Docs duplicate stale Trellis text** -> **Mitigation:** extract decisions and reusable rules, not raw session traces.
- **[Risk] Cleanup deletes operational agent configuration** -> **Mitigation:** only `.opencode/tmp-*` is in cleanup scope; `.opencode/commands/` and `.opencode/skills/` are excluded.
- **[Risk] English/Chinese doc inconsistency** -> **Mitigation:** new docs should be English unless they quote existing Chinese architecture terms.
- **[Risk] Scope creep into baseline commits** -> **Mitigation:** this change only prepares extraction/cleanup; staging and commit remain separate explicit steps.

## Open Questions

- Should `.trellis/tasks/archive/` also be inventoried during apply, or only active task directories?
- Should extracted docs preserve direct links to source Trellis files for traceability?
- After extraction, should `.trellis/tasks/` be committed as historical context, ignored, or cleaned in a later change?
