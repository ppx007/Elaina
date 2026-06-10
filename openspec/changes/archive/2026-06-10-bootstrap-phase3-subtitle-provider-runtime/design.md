## Context

The architecture plan places Phase 3 / Step 15 immediately after the completed Step 14 media library runtime. Step 15 is SubtitleProvider: external subtitle search, retrieval, cache reuse, and parser handoff that enriches basic subtitle playback without becoming concrete UI, network, storage implementation, or advanced caption rendering.

Current code already has many primitives: `SubtitleProvider` search/retrieval contracts, `SubtitleProviderCachePolicy`, provider registration helpers, `SubtitleDiscoveryContract`, `DeterministicSubtitleDiscoveryContract`, subtitle cache records, local subtitle scanning, and conversion from provider files to `SubtitleParseRequest`. The missing piece is a runtime/bootstrap that composes those primitives into a coherent provider-backed subtitle state and action layer, plus tests and validation scripts proving the slice remains layer-isolated.

## Goals / Non-Goals

**Goals:**

- Provide a deterministic `SubtitleProviderRuntime`/bootstrap entry point that composes provider search, provider retrieval, subtitle discovery/cache, and parser handoff behind Domain-facing runtime actions.
- Provide explicit runtime state, snapshot, failure, result, query, candidate, retrieval, and action values for search/retrieve/prepare/select flows.
- Reuse existing `SubtitleProvider`, `SubtitleDiscoveryContract`, `SubtitleCacheStore`, `RetrievedSubtitleFile`, and `SubtitleParseRequest` contracts instead of introducing parallel subtitle-provider models.
- Preserve Step 15 boundaries through focused tests, smoke checks, and PowerShell validation that forbid concrete UI, storage implementation, network clients, RSS, seasonal, BT, online-rule, diagnostics, advanced caption rendering, MPV/VLC, or native-player dependencies.
- Keep deterministic behavior suitable for contract validation before real OpenSubtitles-style clients or persistent database storage are implemented.

**Non-Goals:**

- No concrete OpenSubtitles provider, HTTP client, API key handling, provider SDK, web scraping, captcha flow, or account integration.
- No Flutter subtitle picker UI, playback-page panel, platform file picker, or concrete media-library UI coupling.
- No SQLite schema migration, storage implementation, blob cache behavior, or database-backed subtitle cache.
- No advanced caption rendering, dual subtitle layout, PGS rendering, ASS style enhancement, GPU overlay, diagnostics center, RSS engine, seasonal indexer, BT streaming, online-rule runtime, MPV/VLC/native player, or external service integration.
- No changes to basic subtitle parser behavior beyond consuming stable parser handoff contracts.

## Decisions

1. **Build Step 15 as a Domain/provider subtitle runtime, not a UI subtitle picker.**
   - Rationale: the current repository validates Domain/provider contracts first, and project rules require UI to consume Domain-facing surfaces rather than concrete provider, cache, network, or parser internals.
   - Alternative considered: implement a Flutter subtitle-source picker now. Rejected because Step 15 still needs runtime/state contracts and validation before concrete presentation.

2. **Reuse existing discovery/cache/parser handoff contracts.**
   - Rationale: `subtitle_discovery.dart`, `subtitle_provider.dart`, and subtitle cache contracts already define provider search, retrieval, cache TTL, and parser handoff. The runtime should compose them rather than create duplicate candidate/file/cache models.
   - Alternative considered: create runtime-specific provider candidate and retrieved file types. Rejected because it would duplicate existing Provider and Domain subtitle contracts.

3. **Keep provider behavior deterministic and gateway-bound.**
   - Rationale: this project can validate provider result normalization, cache hits/misses, retrieved content caching, and parser handoff without a concrete network provider.
   - Alternative considered: add a real OpenSubtitles client. Rejected because concrete provider/network implementation belongs in a later adapter/provider slice.

4. **Route retrieved files into basic subtitle parser contracts.**
   - Rationale: Step 15 should prove provider subtitles become `SubtitleParseRequest` values compatible with SRT/VTT/ASS parsing while leaving playback rendering and advanced captions untouched.
   - Alternative considered: let the provider runtime parse subtitles directly. Rejected because parsing already belongs to `basic-subtitle-core`.

5. **Treat cache reuse as contract behavior, not storage implementation.**
   - Rationale: subtitle cache contracts already model search and content TTL. Step 15 should consume those contracts deterministically while leaving durable storage to later persistence implementations.
   - Alternative considered: add a runtime-owned database cache. Rejected because it would force storage migration into this slice.

## Risks / Trade-offs

- **[Risk] Runtime grows into concrete provider/network code.** -> Mitigation: tests and boundary checks forbid HTTP clients, provider SDKs, scraping, storage implementation, network, and concrete UI dependencies.
- **[Risk] Subtitle provider handoff duplicates parser behavior.** -> Mitigation: keep runtime output as `SubtitleParseRequest` and validate parsing through existing basic subtitle runtime smoke checks.
- **[Risk] Cache TTL behavior becomes ambiguous.** -> Mitigation: require tests for cache hit, cache miss, search TTL, content TTL, retrieval storage, and cached parser handoff.
- **[Risk] Step 15 bleeds into Step 16-17 work.** -> Mitigation: explicitly forbid RSS engine, yuc.wiki, seasonal indexer, Bangumi matching queue, and auto-download behavior.

## Migration Plan

1. Add subtitle-provider runtime values, snapshot/result/failure types, query/action values, and a `SubtitleProviderRuntime`/bootstrap composition entry point under `lib/src/domain/subtitle/`.
2. Compose existing `SubtitleProvider`, `SubtitleDiscoveryContract`, subtitle cache contracts, and parser handoff behind the runtime.
3. Add deterministic search/retrieve/prepare actions and observer snapshots.
4. Export safe subtitle-provider runtime surfaces through `lib/celesteria.dart`.
5. Add focused tests, a Dart smoke checker, and a PowerShell boundary checker that chains existing subtitle runtime checks.
6. Run `openspec validate "bootstrap-phase3-subtitle-provider-runtime" --strict`, `openspec validate --all`, `dart analyze`, focused subtitle provider runtime tests, subtitle provider checker scripts, and existing media-library, video detail, subtitle, Bangumi, Dandanplay, and danmaku smoke checks.

Rollback before archive is deleting the new runtime/test/tool files and removing this change directory. No persisted schema, storage migration, provider credentials, network client, platform UI, or native player state is introduced.

## Open Questions

- Whether concrete OpenSubtitles-style provider implementation should live under a dedicated provider adapter slice or be folded into a broader provider registry slice should be decided when real network integration begins.
- Whether subtitle provider UI should consume a Domain snapshot directly or a separate UI contract should be deferred until a concrete playback-page subtitle panel slice.
- Whether provider subtitle retrieval should later publish cache invalidation events remains out of scope until durable cache implementation is introduced.
