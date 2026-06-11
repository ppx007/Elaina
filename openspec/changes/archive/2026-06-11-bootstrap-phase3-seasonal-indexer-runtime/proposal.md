## Why

Phase 3 / Step 16 RSS engine runtime is complete and archived, so the next architecture-plan slice is Phase 3 / Step 17: YucWiki RSS Seasonal Indexer. The project already defines seasonal indexer contracts, RSS feed contracts, Bangumi provider runtime surfaces, and media binding rules, but lacks a deterministic runtime that consumes accepted RSS feed items into seasonal catalog entries and Bangumi match queue work while preserving yuc.wiki as a normal `FeedSource`.

## What Changes

- Add a deterministic Phase 3 seasonal indexer runtime/bootstrap that consumes RSS engine accepted updates, dispatches matching feed items to seasonal consumers, persists normalized seasonal catalog entries, and exposes lifecycle-safe runtime snapshots/results.
- Add yuc.wiki RSS seasonal source registration as ordinary RSS feed source metadata and seasonal consumer configuration, without source-specific scraping, crawler behavior, concrete HTTP clients, or UI subscription flows.
- Add Bangumi match queue orchestration that enqueues normalized seasonal catalog entries through existing provider/binding contracts and never overrides user-confirmed Bangumi bindings.
- Add focused tests and smoke/boundary checks proving Step 17 remains a seasonal-indexer runtime slice and does not expand into RSS auto-download, BT streaming, online-rule parsing, concrete UI, network implementation, diagnostics, or native-player behavior.
- No breaking changes.

## Capabilities

### New Capabilities
- `phase3-seasonal-indexer-runtime`: Deterministic runtime/bootstrap for RSS update consumption, seasonal feed item normalization, seasonal catalog persistence, Bangumi match queue projection, lifecycle snapshots, tests, and validation.

### Modified Capabilities
- `seasonal-anime-indexer`: Existing seasonal indexer foundation gains deterministic runtime, yuc.wiki feed source registration, seasonal consumer dispatch, catalog state projection, and validation requirements while keeping yuc.wiki source-neutral.
- `seasonal-indexer-contract`: Existing seasonal indexer contracts gain runtime consumption requirements for RSS accepted updates, persisted catalog entries, match queue records, automatic match outcomes, and user-confirmed binding priority.
- `repository-baseline`: Repository baseline gains a requirement that Step 17 seasonal indexer runtime remains optional Domain/provider enrichment and must not become a prerequisite for RSS auto-download, BT, online-rule, diagnostics, concrete UI, network implementation, storage migration, or native-player implementations.
- `phase3-rss-engine-runtime`: Existing RSS runtime requirements gain downstream-consumer isolation requirements so seasonal indexing consumes accepted updates without making RSS engine source-specific or seasonal-aware.

## Impact

- Affected code: `lib/src/domain/seasonal/`, RSS runtime update consumers, seasonal storage contract consumers, public Dart barrel exports, focused seasonal indexer runtime tests, runtime smoke checks, and validation scripts.
- Affected specs: new `phase3-seasonal-indexer-runtime` plus deltas for `seasonal-anime-indexer`, `seasonal-indexer-contract`, `repository-baseline`, and `phase3-rss-engine-runtime`.
- Dependencies: no concrete Flutter seasonal page, yuc.wiki scraper, HTTP client, network policy implementation, RSS auto-download execution, BT task creation, online-rule runtime, diagnostics center, MPV/VLC/native player binding, or external service integration is introduced in this slice.
