## Context

The architecture plan places Phase 3 / Step 17 immediately after the completed Step 16 RSS engine runtime. Step 17 is YucWiki RSS Seasonal Indexer: yuc.wiki seasonal RSS remains a normal `FeedSource`, accepted RSS items are consumed by `SeasonalAnimeConsumer`, normalized seasonal catalog entries are persisted, and Bangumi match work is queued without overriding user-confirmed bindings.

Current code already has seasonal domain primitives in `lib/src/domain/seasonal/seasonal_anime.dart`, including `SeasonalSourceItem`, `SeasonalCatalogEntry`, `SeasonalAnimeConsumer`, `DeterministicSeasonalIndexer`, `DeterministicBangumiMatchQueue`, and `DeterministicBangumiMatchWorker`. The missing slice is a Phase 3 runtime/bootstrap surface matching recent runtime slices: lifecycle-safe result/failure/snapshot types, yuc.wiki feed source registration as configuration, catalog and match queue projection actions, deterministic RSS update consumption, smoke/boundary validation, and an OpenSpec runtime capability.

## Goals / Non-Goals

**Goals:**

- Provide a deterministic `SeasonalIndexerRuntime`/bootstrap entry point that composes `RssEngineRuntime` or `RssEngineContract`, `SeasonalAnimeConsumer` instances, `SeasonalCatalogStore`, `BangumiMatchQueueStore`, optional `ProviderBindingStore`, and optional cache invalidation behind Domain-facing actions.
- Provide explicit runtime state, snapshot, failure, result, catalog, source, consumer, match queue, worker, and lifecycle values for source registration, update consumption, catalog projection, queue projection, match processing, and disposed/unavailable behavior.
- Model the YucWiki seasonal feed as ordinary `FeedSource` metadata plus seasonal consumer routing, without scraper, crawler, source-specific parser, HTTP client, cookie/session, or UI subscription behavior.
- Preserve user-confirmed Bangumi binding priority when projecting or applying automatic match work.
- Add focused tests, smoke checks, and boundary validation proving the runtime remains Step 17 seasonal indexing and does not become RSS auto-download, BT, online-rule, concrete UI, network implementation, diagnostics, or native-player code.

**Non-Goals:**

- No concrete yuc.wiki scraper, crawler, HTML parser, concrete RSS/Atom parser package, HTTP client, network policy implementation, or cookie/session handling.
- No Flutter seasonal page, calendar UI, subscription management UI, notifications, settings UI, or concrete source editing screen.
- No RSS engine implementation changes that make RSS source-specific or seasonal-aware; seasonal indexing consumes accepted RSS updates only.
- No RSS auto-download filtering, torrent matching, BT task creation, online-rule parsing, diagnostics center integration, MPV/VLC/native-player behavior, or storage migration implementation.
- No automatic override of user-confirmed Bangumi bindings.

## Decisions

1. **Build Step 17 as a Domain seasonal runtime over existing seasonal contracts.**
   - Rationale: `DeterministicSeasonalIndexer` and Bangumi queue contracts already express the core transformations. The missing part is runtime lifecycle, snapshots, projection, and validation style matching the Step 13-16 runtime slices.
   - Alternative considered: rewrite seasonal indexing from scratch. Rejected because existing contracts already establish catalog persistence and queue semantics.

2. **Use `FeedSource` configuration for YucWiki instead of a special scraper.**
   - Rationale: the architecture explicitly treats yuc.wiki as a normal RSS source. The runtime may provide a deterministic default feed source descriptor, but fetch/parse remains owned by RSS engine contracts.
   - Alternative considered: add YucWiki-specific fetch or parse logic. Rejected because it violates source neutrality and collapses RSS/provider/network boundaries.

3. **Consume RSS accepted updates without changing RSS engine semantics.**
   - Rationale: Step 16 already emits accepted `FeedItem` updates. Step 17 should subscribe to or explicitly process those updates through seasonal consumers without requiring RSS to know about seasons, Bangumi, or catalogs.
   - Alternative considered: add seasonal branches inside RSS refresh. Rejected because downstream consumers must remain independent extension points.

4. **Separate catalog indexing from Bangumi match processing.**
   - Rationale: indexing is deterministic catalog persistence; matching is provider-governed enrichment that may be unavailable, throttled, unauthenticated, or skipped by user-confirmed bindings.
   - Alternative considered: search Bangumi during every RSS item consumption. Rejected because provider access, rate limits, and user binding priority require queue semantics.

5. **Keep persistence as contract consumption.**
   - Rationale: storage contracts already model seasonal catalog entries, match queue items, candidates, and provider bindings. Step 17 should consume those contracts without introducing SQLite migrations or concrete database implementations.
   - Alternative considered: add concrete seasonal tables and repositories now. Rejected because durable storage implementation belongs outside this runtime slice.

## Risks / Trade-offs

- **[Risk] Runtime becomes yuc.wiki-specific scraping.** -> Mitigation: validation rejects scraper/crawler/HTTP/client terms and tests register YucWiki as ordinary `FeedSource` data.
- **[Risk] RSS engine becomes seasonal-aware.** -> Mitigation: runtime consumes accepted updates and boundary checks reject seasonal terms in RSS runtime files.
- **[Risk] Automatic Bangumi matching overwrites user intent.** -> Mitigation: tests cover user-confirmed binding priority and skipped automatic outcomes.
- **[Risk] Provider failures leak into seasonal indexing.** -> Mitigation: match worker returns typed queue outcomes and leaves catalog indexing valid when Bangumi is unavailable.
- **[Risk] Step 17 expands into RSS auto-download or BT.** -> Mitigation: runtime checker forbids auto-download, torrent, BT, online-rule, diagnostics, UI, and native-player dependencies.

## Migration Plan

1. Add seasonal runtime result, failure, snapshot, catalog, match queue, worker, source registration, and lifecycle values under `lib/src/domain/seasonal/`.
2. Implement `SeasonalIndexerRuntime` or `SeasonalIndexerBootstrap` that composes existing RSS runtime/contract updates, seasonal consumers, catalog store, match queue store, binding store, and cache invalidation bus.
3. Add deterministic actions for registering the YucWiki `FeedSource`, processing explicit feed items, starting/stopping update consumption, listing catalog entries, projecting pending match queue state, processing queued Bangumi match work, and disposal.
4. Export safe seasonal runtime surfaces through `lib/elaina.dart` without exporting concrete UI, transport, storage implementation, RSS auto-download execution, BT, online-rule, diagnostics, or native-player code.
5. Add focused tests, a Dart smoke checker, and a PowerShell boundary checker that chains `check_rss_engine_runtime.ps1`.
6. Run `openspec validate "bootstrap-phase3-seasonal-indexer-runtime" --strict`, `openspec validate --all`, `dart analyze`, focused seasonal runtime tests, seasonal checker scripts, and existing RSS/subtitle-provider/media-library/video-detail/subtitle/Bangumi/Dandanplay/danmaku smoke checks.

Rollback before archive is deleting the new runtime/test/tool files and removing this change directory. No persisted schema, concrete RSS fetcher/parser, yuc.wiki scraper, network client, UI, RSS auto-download worker, BT task, online-rule runtime, diagnostics state, or native player state is introduced.

## Open Questions

- Whether real YucWiki title normalization needs locale-specific heuristics should be deferred until concrete feed samples are integrated.
- Whether Bangumi match workers should later be scheduled by background jobs, manual actions, or diagnostics-driven retry policy remains out of scope.
- Whether seasonal catalog UI consumes runtime snapshots directly or a separate UI contract should be deferred until the seasonal/RSS page slice.
