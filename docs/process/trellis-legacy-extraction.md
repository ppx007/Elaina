# Trellis Legacy Extraction

Date: 2026-06-02
Source status: Trellis is legacy context. OpenSpec is the active workflow authority.

## Purpose

This document records which `.trellis/` material still contains durable project knowledge, what has been extracted into stable docs, and which paths should remain legacy-local instead of entering future baseline staging by accident.

The goal is preservation without carrying raw session noise into the repository baseline.

## Inventory

| Source path | Classification | Target action | Rationale |
|---|---|---|---|
| `.trellis/tasks/00-bootstrap-guidelines/prd.md` | keep-legacy | Do not extract beyond this inventory | Generic Trellis bootstrap task for filling placeholder specs. It documents Trellis setup, not a Elaina product decision. |
| `.trellis/tasks/00-bootstrap-guidelines/task.json` | keep-legacy | Do not extract | Runtime task metadata for the legacy Trellis task system. |
| `.trellis/tasks/06-01-save-elaina-player-architecture-plan/prd.md` | extract-to-docs | Summarized in `docs/decisions/phase0-implementation-scope.md` | Records Elaina naming, `1017`, yuc.wiki as RSS `FeedSource`, extension points, and the Phase 0 / Step 1-4 first-slice decision. |
| `.trellis/tasks/06-01-bootstrap-elaina-implementation/prd.md` | extract-to-docs | Summarized in `docs/decisions/phase0-implementation-scope.md` | Confirms the first executable slice is full Phase 0 / Step 1-4 rather than player UI or direct provider integration. |
| `.trellis/tasks/06-01-opencode-trellis-omo-routing/prd.md` | keep-legacy | Mention as superseded workflow history | Records an obsolete OpenCode/Trellis-to-OMO routing plan that was superseded by OpenSpec-first workflow. |
| `.trellis/tasks/archive/` | keep-legacy | No extraction needed | Directory is currently empty. |
| `.trellis/workspace/index.md` | keep-legacy | Do not extract | Generic workspace/session template, not project-specific product knowledge. |
| `.trellis/workspace/px007/index.md` | keep-legacy | Do not extract | Personal workspace index with no completed session history. |
| `.trellis/workspace/px007/journal-1.md` | keep-legacy | Do not extract | Empty journal scaffold. |
| `.trellis/spec/guides/index.md` | extract-to-docs | Reflected in `docs/guides/` docs | Useful trigger list for cross-layer and reuse thinking. |
| `.trellis/spec/guides/cross-layer-thinking-guide.md` | extract-to-docs | Extracted to `docs/guides/cross-layer-thinking.md` | Reusable bug-prevention guidance for cross-layer contracts and runtime template consistency. |
| `.trellis/spec/guides/code-reuse-thinking-guide.md` | extract-to-docs | Extracted to `docs/guides/code-reuse-thinking.md` | Reusable guidance for search-first reuse, abstraction timing, and asymmetric output mechanisms. |
| `.trellis/workflow.md` | extract-to-docs | Process principles summarized here | Useful legacy process principles: plan first, persist decisions in files, update specs after learning. Command templates remain Trellis-specific and are not copied. |
| `.trellis/scripts/` | keep-legacy | Protected from cleanup | Scripts are operational Trellis history and are not garbage. |
| `.opencode/tmp-check.ps1` | confirm-garbage | Documented in `docs/process/repository-baseline-cleanup.md` | One-off OpenSpec cleanup/check script from archive troubleshooting. |
| `.opencode/tmp-cleanup.cmd` | confirm-garbage | Documented in `docs/process/repository-baseline-cleanup.md` | One-off cleanup script for an already-resolved active-change leftover. |
| `.opencode/tmp-cleanup.js` | confirm-garbage | Documented in `docs/process/repository-baseline-cleanup.md` | One-off Node cleanup script for the same resolved leftover. |

## Extracted Decisions

The project-level decisions extracted from Trellis task PRDs are now recorded in `docs/decisions/phase0-implementation-scope.md`:

- The product name is `Elaina`; `1017` remains a code name or abbreviation.
- The first implementation slice is full Phase 0 / Step 1-4: layered boundaries, local storage foundation, `ProviderGateway`, and `CacheInvalidationBus`.
- The project must not start from player UI, playback-page interaction, or direct provider integration.
- yuc.wiki is an RSS `FeedSource`, not a hardcoded scraper or privileged online provider.
- Player, provider, RSS, storage, network policy, enhancement profile, and diagnostics integrations remain extension points.

## Extracted Guides

The reusable thinking guides were promoted into stable human docs:

- `docs/guides/cross-layer-thinking.md`
- `docs/guides/code-reuse-thinking.md`

The extracted docs keep the useful checklists and project-relevant examples while dropping Trellis command-template noise where it is only about maintaining Trellis itself.

## Protected Assets

The following paths must not be classified as garbage by this cleanup pass:

- `.trellis/scripts/`
- `.trellis/spec/guides/`
- `openspec/`
- `docs/`
- `lib/`
- `tools/`
- root manifests and root agent instructions
- `.opencode/commands/`, `.opencode/skills/`, `.opencode/package.json`, and `.opencode/package-lock.json`

## Future Disposition

After these docs are reviewed, a future staging or cleanup change can decide whether to commit `.trellis/tasks/` as historical context, leave it local, or remove selected logs. This apply step only extracts and classifies; it does not delete Trellis history.
