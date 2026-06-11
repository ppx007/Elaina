## Why

Phase 3 / Step 15 subtitle provider runtime is complete and archived, so the architecture plan's next slice is Phase 3 / Step 16: RSS Engine foundation. Existing contracts define `FeedSource`, `FeedFetcher`, `FeedParser`, `FeedScheduler`, deduplication, persisted feed state, and Domain refresh results, but there is no deterministic runtime/bootstrap that composes those pieces into a lifecycle-safe RSS engine surface with source registration, schedule decisions, gateway-backed fetch handoff, parser handoff, dedupe persistence, update emission, and validation boundaries.

## What Changes

- Add a deterministic Phase 3 RSS engine runtime/bootstrap that wires feed source registry, feed scheduler, feed fetcher, feed parser, feed deduplicator, feed store, cursor persistence, and Domain update emission behind RSS Domain-facing surfaces.
- Add runtime result, snapshot, lifecycle, source, refresh, schedule, cursor, dedupe, and update outcomes for RSS/Atom refresh flows without introducing concrete HTTP clients, Flutter UI, yuc.wiki-specific scraping, seasonal normalization, RSS auto-download rules, BT task creation, online-rule parsing, diagnostics, MPV/VLC, or native-player bindings.
- Add deterministic RSS engine actions for source registration, due-source projection, conditional fetch metadata reuse, gateway-normalized fetch failure propagation, parser warning preservation, duplicate suppression, accepted-item persistence, cursor updates, and update stream emission.
- Add focused tests and smoke/boundary checks proving Step 16 remains an RSS engine runtime slice and does not expand into Step 17 seasonal indexing, yuc.wiki special-case logic, RSS auto-download, BT streaming, online rules, concrete UI, network implementation, diagnostics, or native-player code.
- No breaking changes.

## Capabilities

### New Capabilities
- `phase3-rss-engine-runtime`: Deterministic runtime/bootstrap for RSS/Atom source registration, scheduling, refresh orchestration, conditional fetch metadata, parser handoff, deduplication, persisted accepted items, update emission, lifecycle snapshots, tests, and validation.

### Modified Capabilities
- `rss-engine-foundation`: Existing RSS foundation contracts gain deterministic runtime, source registration, scheduler consumption, parser/fetch/dedupe composition, lifecycle, and validation requirements while remaining source-neutral and scraping-neutral.
- `rss-engine-contract`: Existing RSS engine contracts gain runtime consumption requirements for persisted feed state, cursor validators, dedupe keys, accepted item emission, and gateway-normalized refresh outcomes without concrete transport or database implementation.
- `repository-baseline`: Repository baseline gains a requirement that Step 16 RSS engine runtime remains optional Domain/provider enrichment and must not become a prerequisite for seasonal indexer, RSS auto-download, BT, online-rule, diagnostics, concrete UI, network implementation, or native-player implementations.

## Impact

- Affected code: `lib/src/domain/rss/`, `lib/src/provider/rss/`, RSS feed storage contract consumers, public Dart barrel exports, focused RSS engine runtime tests, runtime smoke checks, and validation scripts.
- Affected specs: new `phase3-rss-engine-runtime` plus deltas for `rss-engine-foundation`, `rss-engine-contract`, and `repository-baseline`.
- Dependencies: no concrete Flutter RSS page, HTTP client, network policy implementation, yuc.wiki scraper, seasonal anime consumer/runtime, Bangumi matching queue, RSS auto-download policy execution, BT task creation, online-rule runtime, diagnostics center, MPV/VLC/native player binding, or external service integration is introduced in this slice.
