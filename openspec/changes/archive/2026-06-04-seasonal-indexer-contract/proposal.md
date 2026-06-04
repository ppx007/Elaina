## Why

Step 17 needs the seasonal anime indexer to turn the RSS engine foundation into a durable seasonal catalog pipeline. The just-archived RSS engine intentionally kept YucWiki normalization out of scope, leaving the next plan-aligned gap at `SeasonalAnimeConsumer`, seasonal catalog persistence, and the Bangumi match queue.

## What Changes

- Add a Domain seasonal indexing contract that consumes RSS engine updates, maps accepted feed items into seasonal source items, invokes `SeasonalAnimeConsumer`, and persists normalized seasonal catalog entries.
- Add Storage-layer seasonal catalog and Bangumi match queue stores so seasonal entries, queued candidates, and queue state do not live in Provider or UI code.
- Add a Bangumi match queue worker contract that searches through `BangumiProvider`, preserves candidates, and applies automatic matches without overriding user-confirmed bindings.
- Add cache invalidation events for seasonal catalog updates, Bangumi match enqueueing, and automatic match application.
- Keep yuc.wiki as a normal `FeedSource` plus consumer path, not as a special scraper or concrete HTTP/XML implementation.

## Capabilities

### New Capabilities

- `seasonal-indexer-contract`: Domain and Storage contracts for RSS-driven seasonal catalog indexing, Bangumi match queue persistence, and automatic match application.

### Modified Capabilities

- `seasonal-anime-indexer`: Refine the bootstrap seasonal indexer requirements into durable catalog and queue orchestration behavior.
- `local-storage-foundation`: Add seasonal catalog and Bangumi match queue persistence responsibilities.
- `rss-engine-contract`: Clarify that seasonal consumers subscribe to the RSS engine update stream without becoming part of core feed refresh.
- `cache-invalidation-bus`: Add seasonal catalog and Bangumi match queue invalidation events.
- `bangumi-provider-boundary`: Add queue-driven subject search and automatic binding behavior requirements.

## Impact

Affected code includes Domain seasonal contracts, Storage foundation records/stores, RSS-to-seasonal orchestration, Bangumi provider queue integration, cache invalidation events, runtime/checker validation, and contract tests. No UI, concrete yuc.wiki HTTP/XML parser, RSS auto-download rules, BT enqueueing, background scheduler, or provider-specific scraping is part of this change.
