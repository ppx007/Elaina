## Context

The architecture plan places Phase 3 / Step 16 immediately after the completed Step 15 subtitle provider runtime. Step 16 is RSS Engine foundation: `FeedSource`, `FeedFetcher`, `FeedParser`, `FeedScheduler`, stable deduplication, cursor metadata, persisted feed state, and Domain refresh/update results.

Current code already has RSS primitives in `lib/src/domain/rss/rss_engine.dart`, provider contracts in `lib/src/provider/rss/feed_contracts.dart`, and storage contracts in `RssFeedStore`. `DeterministicRssEngine` can register sources and refresh a single source, but the slice is not yet shaped like the recent Phase 3 runtimes: there is no bootstrap/runtime facade with lifecycle snapshots, due-source scheduling actions, source registry projection, refresh result history, unavailable/disposed behavior, Step 16 smoke checker, PowerShell boundary checker, or OpenSpec runtime capability.

## Goals / Non-Goals

**Goals:**

- Provide a deterministic `RssEngineRuntime`/bootstrap entry point that composes `RssEngineContract`, `FeedScheduler`, `RssFeedStore`, feed fetch/parser/dedupe contracts, and update streams behind Domain-facing runtime actions.
- Provide explicit runtime state, snapshot, failure, result, source, schedule, refresh, cursor, dedupe, and lifecycle values for source registration, source listing, due-source projection, refresh execution, and accepted-item update emission.
- Reuse existing `FeedSource`, `FeedFetcher`, `FeedParser`, `FeedDeduplicator`, `RssFeedStore`, `FeedItem`, and `RssRefreshOutcome` contracts instead of introducing parallel RSS feed models.
- Preserve conditional fetch metadata and stable dedupe behavior through existing cursor/dedupe storage contracts while leaving durable database implementation out of scope.
- Add focused tests, smoke checks, and boundary validation proving the runtime remains source-neutral and does not become seasonal indexing, yuc.wiki scraping, RSS auto-download, BT, online-rule, concrete UI, network implementation, diagnostics, or native-player code.

**Non-Goals:**

- No concrete HTTP client, network policy implementation, RSS provider SDK, web scraper, crawler, cookie/session handling, or yuc.wiki-specific parser.
- No Flutter RSS page, subscription management UI, settings UI, notification UI, or concrete source editing screen.
- No seasonal anime normalization, `SeasonalAnimeConsumer` runtime, Bangumi match queue worker, automatic Bangumi subject search, or yuc.wiki special-case behavior.
- No RSS auto-download filtering, torrent matching, BT task creation, online-rule parsing, diagnostics center integration, MPV/VLC/native-player behavior, or storage migration implementation.
- No changes to existing feed item, fetcher, parser, or store contracts except runtime consumption requirements and validation boundaries.

## Decisions

1. **Build Step 16 as a Domain RSS runtime, not a concrete RSS network/provider client.**
   - Rationale: the current repository validates deterministic Domain/provider orchestration before concrete adapters. RSS fetch traffic must remain represented by `FeedFetcher` and ProviderGateway-bound result contracts.
   - Alternative considered: implement an HTTP RSS fetcher now. Rejected because concrete transport and network policy implementation belong in later adapter/network slices.

2. **Treat yuc.wiki as testable data only through generic `FeedSource` contracts.**
   - Rationale: the architecture explicitly says yuc.wiki is just another `FeedSource`, and Step 17 owns seasonal indexing. Step 16 must prove RSS engine neutrality.
   - Alternative considered: add a YucWiki-specific runtime action. Rejected because that would collapse Step 16 and Step 17 boundaries.

3. **Layer runtime actions over existing `DeterministicRssEngine` instead of replacing it.**
   - Rationale: existing engine code already proves fetch/parse/dedupe/persist/cursor behavior. The missing part is a Phase 3 runtime facade with snapshots, lifecycle, scheduling, registry projection, and validation style matching Steps 13-15.
   - Alternative considered: rewrite `DeterministicRssEngine` as the only public runtime. Rejected because the lower-level engine contract remains useful for provider/consumer tests.

4. **Make scheduling deterministic and explicit.**
   - Rationale: tests need due-source projection without timers or background services. The runtime should consume `FeedScheduler` decisions and expose refreshable sources without owning platform scheduling.
   - Alternative considered: add timer-based background polling. Rejected because background services and platform lifecycle policy are not part of this slice.

5. **Keep persistence as contract consumption.**
   - Rationale: `RssFeedStore` already models sources, items, cursors, and dedupe keys. Step 16 should consume those contracts without introducing SQLite migrations or concrete database implementations.
   - Alternative considered: add a concrete database-backed RSS store. Rejected because storage implementation is outside this runtime slice.

## Risks / Trade-offs

- **[Risk] Runtime bleeds into Step 17 seasonal behavior.** -> Mitigation: tests and boundary checks forbid seasonal consumer, Bangumi match queue worker, and yuc.wiki-specific runtime logic.
- **[Risk] Scheduler behavior becomes platform background work.** -> Mitigation: runtime exposes deterministic due-source actions and leaves timers/background services out of scope.
- **[Risk] Fetch failures become transport-specific.** -> Mitigation: preserve `AcgProviderFailureKind` and `AcgProviderResult` semantics from `FeedFetcher` rather than catching concrete HTTP errors.
- **[Risk] Deduplication happens twice or inconsistently.** -> Mitigation: require tests for in-memory deduplicator retention and persisted `RssFeedStore.hasDedupeKey` suppression.
- **[Risk] Existing `DeterministicRssEngine` lacks disposed semantics.** -> Mitigation: add runtime-level lifecycle guards and close behavior without forcing every lower-level contract to own lifecycle state.

## Migration Plan

1. Add RSS engine runtime values, snapshot/result/failure types, source registry projection, schedule decisions, action results, and lifecycle state under `lib/src/domain/rss/`.
2. Implement `RssEngineRuntime` or `RssEngineBootstrap` that composes existing `RssEngineContract`, `FeedScheduler`, `RssFeedStore`, and feed update streams.
3. Add deterministic source registration/listing/removal, due-source projection, refresh one source, refresh due sources, update observation, and disposed/unavailable outcomes.
4. Export safe RSS runtime surfaces through `lib/celesteria.dart` without exporting concrete UI, transport, storage implementation, seasonal runtime, or auto-download execution code.
5. Add focused tests, a Dart smoke checker, and a PowerShell boundary checker that chains `check_subtitle_provider_runtime.ps1`.
6. Run `openspec validate "bootstrap-phase3-rss-engine-runtime" --strict`, `openspec validate --all`, `dart analyze`, focused RSS runtime tests, RSS checker scripts, and existing subtitle-provider, media-library, video-detail, subtitle, Bangumi, Dandanplay, and danmaku smoke checks.

Rollback before archive is deleting the new runtime/test/tool files and removing this change directory. No persisted schema, concrete fetcher, background scheduler, seasonal indexer, auto-download worker, BT task, UI, network client, diagnostics state, or native player state is introduced.

## Open Questions

- Whether concrete RSS/Atom parsing should later live as a provider adapter, parser utility, or dedicated package integration should be decided when real network/feed integration begins.
- Whether RSS update streams should later publish cache invalidation events remains out of scope until durable RSS consumers are implemented.
- Whether source subscription UI consumes runtime snapshots directly or a separate UI contract should be deferred until an RSS page slice.
