## Why

Phase 6 Step 26 is the first automation-extension slice: RSS auto-download policies that consume the existing RSS Engine and hand accepted candidates to engine-neutral BT task contracts. The bootstrap policy spec names declarative matching, durable history, deduplication, and optional automation, but it lacks durable policy storage, typed evaluation/enqueue outcomes, invalidation events, runtime checks, and checker coverage comparable to completed Phase 5 contract slices.

## What Changes

- Add durable RSS auto-download policy storage contracts for global/feed-scoped policies, matcher rules, evaluation history, accepted candidates, rejected candidates, and enqueue outcomes.
- Deepen RSS auto-download policy contracts with typed policy registration, evaluation, acceptance, rejection, deduplication, disable, and BT handoff outcomes/failures.
- Add a deterministic policy evaluator that consumes existing `FeedItem` data after RSS parsing/deduplication and emits engine-neutral BT task create requests without concrete torrent engine APIs.
- Publish automation invalidation events when policies change, feed items are evaluated, candidates are accepted/rejected, dedup state changes, or BT enqueue handoff outcomes are recorded.
- Preserve optional automation semantics: RSS automation is capability-gated and never required for local playback, media-library use, manual BT task creation, core playback startup, online source parsing, or yuc.wiki-specific scraping.
- Add focused tests, runtime checks, Phase 6 checker rules, and documentation proving Step 26 remains declarative, RSS-engine-consuming, and engine-neutral.

## Capabilities

### New Capabilities
- `rss-auto-download-policy-contract`: Durable Step 26 contract for RSS auto-download policy storage, typed evaluation, deduplication, BT handoff, invalidation, and optional automation behavior.

### Modified Capabilities
- `rss-auto-download-policy`: Refine the bootstrap RSS auto-download policy into typed outcomes, deterministic declarative matching, durable history, and optional capability gating semantics.
- `rss-engine-contract`: Clarify that auto-download policies consume accepted feed items from the existing RSS Engine rather than owning a parallel feed engine.
- `local-storage-foundation`: Add RSS auto-download persistence responsibilities for policy records, matcher rules, evaluation history, accepted/rejected candidates, and enqueue outcomes.
- `cache-invalidation-bus`: Add RSS automation invalidation events for policy changes, item evaluation, candidate acceptance/rejection, dedup state, and enqueue outcome changes.
- `bt-task-core-contract`: Clarify that RSS automation hands accepted candidates to engine-neutral BT task creation contracts without importing concrete torrent-engine APIs.

## Impact

- Affected Dart contracts are expected under `lib/src/domain/rss/`, `lib/src/foundation/storage/`, `lib/src/foundation/cache_invalidation/`, `lib/src/streaming/`, and `lib/elaina.dart`.
- New storage contract file expected under `lib/src/foundation/storage/` for RSS auto-download policy persistence.
- Verification updates expected in `test/domain/rss/` or `test/provider/rss/`, `tools/player_core_runtime_check.dart` or an automation runtime checker, `tools/check_automation_extension_core.ps1`, and `docs/phase6-automation-extension-core.md`.
- No new external dependencies, concrete torrent engines, libtorrent bindings, RSS fetch/parse duplication, online source crawlers, yuc.wiki special cases, JavaScript/WASM rule execution, WebView challenge handling, DNS/network policy behavior, diagnostics actions, Flutter UI, or mandatory automation startup path.
