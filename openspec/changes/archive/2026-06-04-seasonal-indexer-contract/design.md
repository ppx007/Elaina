## Context

Step 17 follows the archived RSS engine foundation. Existing contracts already define `FeedSource`, RSS refresh results, `SeasonalAnimeConsumer`, `SeasonalCatalogEntry`, `BangumiMatchQueue`, and Bangumi provider lookup/search boundaries, but the pieces are not yet connected through durable Storage or cache invalidation.

## Goals / Non-Goals

**Goals:**
- Persist seasonal catalog entries and Bangumi match queue state through Storage-layer contracts.
- Define Domain orchestration that consumes RSS engine updates, invokes seasonal consumers, persists normalized entries, and queues Bangumi matching.
- Define a deterministic Bangumi match worker contract that searches providers, stores candidates, and applies automatic matches only when user-confirmed bindings are absent.
- Publish cache invalidation events for seasonal catalog and match queue mutations.

**Non-Goals:**
- No concrete yuc.wiki HTTP client, scraper, XML parser, or source-specific transport.
- No UI seasonal page or subscription management screen.
- No RSS auto-download, torrent enqueueing, or BT integration.
- No background OS scheduling, long-running service, or fuzzy title matching algorithm beyond contract shape.

## Decisions

1. **Seasonal state belongs to Storage, not Provider.**
   `SeasonalCatalogStore` and `BangumiMatchQueueStore` keep normalized catalog entries, queue items, candidates, and queue status durable without letting RSS providers own persistence.

2. **Domain owns RSS-to-seasonal orchestration.**
   A Domain `SeasonalIndexerContract` SHALL consume `RssEngineContract.updates` as the RSS handoff surface, filter by accepted `SeasonalFeedSourceId`, and call registered `SeasonalAnimeConsumer` instances. It must not trigger feed refreshes directly or depend on concrete fetcher/parser implementations. RSS remains source-neutral; seasonal consumers own normalization.

3. **Bangumi matching is queue-driven enrichment.**
   A match worker contract should use `BangumiProvider.searchSubjects()` through provider boundaries, store candidate lists, and apply automatic bindings through `ProviderBindingRepository.saveAutomaticIfAllowed()` so user-confirmed bindings remain authoritative. Deterministic automatic matching should use a fixed `0.8` minimum confidence threshold until a later configurable policy exists.

4. **Invalidation uses bus events.**
   Seasonal catalog updates, queued match items, and applied automatic matches should publish dedicated `CacheInvalidationEvent` types instead of direct cross-module cache mutation.

5. **Seasonal storage may split from the monolithic storage file.**
   `storage_contracts.dart` already contains the shared Storage foundation plus multiple deterministic stores. Seasonal catalog and match queue records may live in a dedicated seasonal storage contract file, with `StorageFoundation` exposing the final stores, if that keeps the Storage layer easier to read without changing layer ownership.

## Risks / Trade-offs

- [Consumer leakage into RSS core] -> Keep consumer registration and dispatch in Domain seasonal contracts, not in `DeterministicRssEngine` internals.
- [Automatic matching overrides user intent] -> Route all automatic binding through `saveAutomaticIfAllowed()` and preserve explicit skipped outcomes.
- [YucWiki becomes a special scraper path] -> Treat it only as a `FeedSource` plus `SeasonalAnimeConsumer`; concrete fetching/parsing remains RSS provider work.
- [Queue durability grows too broad] -> Store queue item status and candidates now; defer retry timestamps, scheduling jitter, and diagnostics history.

## Migration Plan

1. Add seasonal catalog and Bangumi match queue records/stores to Storage foundation.
2. Add Domain seasonal indexer and deterministic queue worker contracts.
3. Add cache invalidation event types for catalog and match queue mutations.
4. Add contract tests and runtime/checker validation.

## Open Questions

- None for the current contract boundary. Retry timestamps, scheduling jitter, and diagnostics history are deferred; deterministic automatic matching uses a fixed `0.8` minimum confidence threshold for this slice.
