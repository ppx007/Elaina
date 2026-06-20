## 1. Domain RSS Engine Runtime

- [x] 1.1 Add RSS engine runtime result, failure, snapshot, observer, source registry, schedule, refresh, cursor, dedupe, update, and lifecycle value objects under `lib/src/domain/rss/` with deterministic disposed and unavailable behavior.
- [x] 1.2 Implement an `RssEngineRuntime` or `RssEngineBootstrap` composition entry point that wires `RssEngineContract`, `FeedScheduler`, `RssFeedStore`, feed fetch/parser/dedupe contracts, and update streams.
- [x] 1.3 Add deterministic source registration, source removal, source listing, source lookup, cursor snapshot, dedupe snapshot, and accepted item projection actions without concrete UI, storage implementation, network client, seasonal, auto-download, BT, online-rule, diagnostics, or native-player models.
- [x] 1.4 Implement deterministic due-source projection that consumes `FeedScheduler` decisions for registered `FeedSource` values without timers, platform background services, subscription UI, or source-specific scraping.
- [x] 1.5 Implement deterministic refresh actions for explicit sources and due sources that preserve conditional fetch metadata, parser warnings, gateway-normalized provider failures, duplicate suppression, accepted item persistence, cursor updates, and update emission.
- [x] 1.6 Implement lifecycle-safe success, ignored, unavailable, failed, and disposed outcomes for source, schedule, refresh, and update observation flows without leaking provider, parser, storage, scheduler, stream, UI, network, seasonal, BT, online-rule, diagnostics, or native-player exceptions.

## 2. Source Neutrality, Exports, and Boundaries

- [x] 2.1 Reuse existing `FeedSource`, `FeedFetcher`, `FeedParser`, `FeedDeduplicator`, `RssFeedStore`, `FeedItem`, `RssRefreshOutcome`, and ProviderGateway result contracts instead of introducing parallel RSS feed, source, item, fetch, parser, cursor, or dedupe models.
- [x] 2.2 Keep yuc.wiki modeled only as a normal `FeedSource` and ensure RSS engine runtime does not implement yuc.wiki-specific scraping, seasonal normalization, Bangumi match queue work, RSS auto-download filtering, torrent task creation, online-rule parsing, or UI behavior.
- [x] 2.3 Export only safe RSS runtime and contract surfaces through `lib/elaina.dart` without exporting concrete Flutter RSS pages, HTTP clients, concrete storage implementations, seasonal runtime, auto-download execution, BT runtime, online-rule runtime, diagnostics, or native-player bindings.
- [x] 2.4 Preserve existing subtitle-provider, media-library, video-detail, subtitle, Bangumi, Dandanplay, and danmaku runtime checker behavior while extending validation for the Step 16 RSS engine runtime slice.

## 3. Tests and Validation

- [x] 3.1 Add focused RSS engine runtime tests for source registration, source listing/removal, immutable snapshots, cursor projection, dedupe projection, accepted item projection, update observation, and runtime lifecycle snapshots.
- [x] 3.2 Add schedule and refresh tests for due-source projection, explicit refresh, refresh-due flow, parser format mismatch, missing source, provider failure normalization, parser warning preservation, conditional fetch metadata reuse, and disposed behavior.
- [x] 3.3 Add dedupe and persistence tests for in-memory duplicate suppression, persisted dedupe key suppression after restart-like conditions, accepted item storage, cursor storage, update emission of only accepted items, and immutable result surfaces.
- [x] 3.4 Add boundary tests or script checks proving RSS engine runtime does not own concrete HTTP clients, network implementation, source-specific scraping, seasonal indexer, Bangumi match workers, RSS auto-download execution, BT task creation, online-rule parsing, diagnostics, UI widgets, MPV/VLC, or native-player behavior.
- [x] 3.5 Add `tools/rss_engine_runtime_check.dart` smoke validation covering runtime source registration, due-source projection, refresh success, duplicate suppression, cursor reuse, provider failure normalization, update emission, and existing subtitle-provider/media-library/video-detail/Phase 2 smoke checks.
- [x] 3.6 Add `tools/check_rss_engine_runtime.ps1` boundary validation that chains `check_subtitle_provider_runtime.ps1` and rejects forbidden Step 17+ / Phase 4+ / concrete UI / HTTP client / network implementation / source-specific scraper / seasonal / auto-download / BT / online-rule / diagnostics / native-player dependencies in Step 16 runtime files.
- [x] 3.7 Run `openspec validate "bootstrap-phase3-rss-engine-runtime" --strict`, `openspec validate --all`, `dart analyze`, focused RSS engine runtime tests, RSS checker scripts, and existing subtitle-provider, media-library, video-detail, subtitle, Bangumi, Dandanplay, and danmaku runtime smoke checks.
