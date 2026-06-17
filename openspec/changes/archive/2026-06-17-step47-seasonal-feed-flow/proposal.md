## Why

Step 46 added concrete RSS/Atom fetching and parsing, and the archived Phase 3
seasonal runtime can consume accepted `FeedItem` updates into seasonal catalog
entries plus Bangumi match queue records. The missing Step 47 slice is the
non-UI core flow that composes these pieces deterministically:

```text
FeedSource refresh -> accepted FeedItem -> SeasonalAnimeConsumer
  -> SeasonalCatalogStore -> BangumiMatchQueueStore
```

Without this flow, app composition has to manually coordinate RSS refreshes,
seasonal item consumption, and queue projection, which is easy to race if it
relies only on asynchronous update listeners.

## What Changes

- Add a Domain-level seasonal feed flow runtime:
  - registers seasonal feed sources through `SeasonalIndexerRuntime`;
  - refreshes sources through `RssEngineRuntime`;
  - passes accepted refresh items directly into `SeasonalIndexerRuntime`;
  - returns typed, immutable refresh snapshots with catalog and match queue
    projections.
- Add a reusable `FeedItemSeasonalAnimeConsumer` for source-neutral seasonal
  feed items:
  - accepts an explicit seasonal source id and season;
  - maps feed title/link/summary/publication into `SeasonalCatalogEntry`;
  - derives catalog ids from a named prefix instead of inline literals.
- Add focused tests and non-UI smoke tooling that compose Step 46 concrete
  fetch/parser with the seasonal flow.
- Add integration notes for app/runtime composition.

## Non-Goals

- No `lib/src/ui/**`, `lib/main.dart`, or `windows/**` changes.
- No RSS pages, subscription management UI, routing, widgets, file picker, or
  visual state composition.
- No yuc.wiki scraper/crawler/source-specific parser.
- No RSS auto-download, BT enqueueing, online-rule runtime, WebView, diagnostics
  center, network-policy implementation, native player, or background scheduler
  implementation.
- No automatic Bangumi provider search in the refresh flow; Step 47 queues
  Bangumi work and leaves explicit match processing to existing runtime actions.

## Impact

- Affected code is limited to seasonal Domain flow/runtime contracts, tests,
  tools/checkers, docs, public exports, and OpenSpec specs.
- Existing deterministic seasonal indexer and RSS engine behavior remains
  compatible.
