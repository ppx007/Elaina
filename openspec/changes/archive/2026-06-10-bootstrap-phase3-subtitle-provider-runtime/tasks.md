## 1. Domain Subtitle Provider Runtime

- [x] 1.1 Add subtitle-provider runtime result, failure, snapshot, observer, query, candidate, retrieval, parser-handoff, and lifecycle value objects under `lib/src/domain/subtitle/` with deterministic disposed/unavailable behavior.
- [x] 1.2 Implement a `SubtitleProviderRuntime` or `SubtitleProviderBootstrap` composition entry point that wires `SubtitleProvider`, `SubtitleDiscoveryContract`, subtitle cache contracts, retrieved subtitle files, and parser handoff.
- [x] 1.3 Add deterministic subtitle discovery projection that combines local subtitle candidates, provider subtitle candidates, cache-hit state, provider failures, retrieved files, and `SubtitleParseRequest` values without provider-specific, UI-specific, storage-specific, playback-specific, or native-player-specific duplicate models.
- [x] 1.4 Implement deterministic search actions that normalize `SubtitleDiscoveryRequest`, expose local/provider candidates, preserve `fromCache`, and report typed provider failures without concrete provider clients, network calls, UI widgets, or storage implementations.
- [x] 1.5 Implement deterministic retrieval/prepare actions that route selected `SubtitleProviderCandidate` values through `SubtitleDiscoveryContract.prepareProviderSubtitle`, preserve retrieved content and encoding hints, and return parser-compatible handoff outcomes.
- [x] 1.6 Implement lifecycle-safe unavailable, unsupported, ignored, failed, and disposed action outcomes for search/retrieve/prepare flows without leaking provider, storage, UI, network, playback, or native-player exceptions.

## 2. Cache, Exports, and Boundaries

- [x] 2.1 Consume existing subtitle cache contracts for provider search and content cache hit/miss behavior without introducing SQLite migrations, blob cache writes, file cache implementation, or persistent runtime caches.
- [x] 2.2 Keep subtitle-provider runtime files provider-boundary-safe and ensure they do not import concrete Flutter widgets, storage implementations, RSS, seasonal indexer, BT, online-rule, diagnostics, advanced caption rendering, network clients, OpenSubtitles SDKs, scraping/crawler code, captcha automation, MPV/VLC, or native-player bindings.
- [x] 2.3 Export only safe subtitle-provider runtime and contract surfaces through `lib/elaina.dart` without exporting concrete Flutter subtitle pages, concrete provider clients, or storage implementations.
- [x] 2.4 Preserve existing subtitle runtime, media-library runtime, and detail/library/seasonal checker behavior while extending validation for the Step 15 subtitle-provider runtime slice.

## 3. Tests and Validation

- [x] 3.1 Add focused subtitle-provider runtime tests for provider search success, local/provider candidate composition, cache-hit search reuse, provider failure normalization, runtime snapshots, and disposed behavior.
- [x] 3.2 Add retrieval/parser-handoff tests for cached content reuse, provider retrieval storage, retrieved content/encoding preservation, supported SRT/VTT/ASS format handoff, unavailable candidates, and immutable result surfaces.
- [x] 3.3 Add boundary tests or script checks proving subtitle-provider runtime does not own concrete provider clients, network requests, storage migrations, UI widgets, RSS, seasonal, BT, online-rule, diagnostics, advanced captions, MPV/VLC, native-player behavior, scraping, or captcha automation.
- [x] 3.4 Add `tools/subtitle_provider_runtime_check.dart` smoke validation covering provider search, cached search, retrieval, cached content handoff, parser request compatibility, and existing subtitle/media/video-detail/Phase 2 smoke checks.
- [x] 3.5 Add `tools/check_subtitle_provider_runtime.ps1` boundary validation that chains `check_media_library_runtime.ps1` and rejects forbidden Step 16+ / Phase 4+ / concrete UI / provider client / storage implementation / network / advanced-caption / native-player dependencies in Step 15 runtime files.
- [x] 3.6 Run `openspec validate "bootstrap-phase3-subtitle-provider-runtime" --strict`, `openspec validate --all`, `dart analyze`, focused subtitle-provider runtime tests, subtitle-provider checker scripts, and existing media-library, video detail, subtitle, Bangumi, Dandanplay, and danmaku runtime smoke checks.
