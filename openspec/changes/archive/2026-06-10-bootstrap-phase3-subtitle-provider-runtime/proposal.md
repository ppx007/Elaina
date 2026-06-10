## Why

Phase 3 / Step 14 media library runtime is complete and archived, so the architecture plan's next slice is Phase 3 / Step 15: SubtitleProvider. Existing contracts define subtitle provider search/retrieval, cache records, local/provider discovery, and parser handoff, but there is no deterministic runtime/bootstrap that composes provider-backed subtitle discovery into a usable Domain surface with lifecycle snapshots, normalized failures, cache-aware selection, and validation boundaries.

## What Changes

- Add a deterministic Phase 3 subtitle provider runtime/bootstrap that wires `SubtitleProvider`, `SubtitleDiscoveryContract`, subtitle cache contracts, parser handoff, and basic subtitle runtime-compatible parse requests behind Domain-facing surfaces.
- Add runtime result, snapshot, lifecycle, query, candidate, retrieval, cache, and parser-handoff outcomes for provider subtitle search/retrieve/select flows without introducing concrete OpenSubtitles HTTP clients, Flutter UI, storage migrations, advanced caption rendering, RSS, seasonal indexing, BT, online-rule, diagnostics, MPV/VLC, or native-player bindings.
- Add deterministic subtitle provider actions for provider search, cached search reuse, provider failure normalization, subtitle retrieval, content cache reuse, parser request handoff, supported format preservation, and local/provider candidate composition.
- Add focused tests and smoke/boundary checks proving Step 15 remains a subtitle-provider runtime slice and does not expand into RSS engine, seasonal indexer, BT streaming, online rules, concrete UI, storage implementation, advanced caption rendering, diagnostics, or native-player code.
- No breaking changes.

## Capabilities

### New Capabilities
- `phase3-subtitle-provider-runtime`: Deterministic runtime/bootstrap for subtitle provider search, retrieval, cache-aware discovery, parser handoff, lifecycle snapshots, tests, and validation.

### Modified Capabilities
- `subtitle-provider-boundary`: Existing subtitle provider contracts gain deterministic runtime, provider search/retrieval action, normalized failure, and parser-handoff requirements while remaining ProviderGateway-, cache-, UI-, storage-implementation-, and native-player-neutral.
- `subtitle-provider-cache-contract`: Subtitle cache contracts gain deterministic runtime consumption requirements for search/content TTL reuse, cache misses, cache hits, retrieved content storage, and parser handoff without concrete database implementation.
- `basic-subtitle-core`: Basic subtitle contracts gain runtime handoff requirements proving provider-retrieved files remain compatible with SRT/VTT/ASS parser requests without advanced rendering behavior.
- `repository-baseline`: Repository baseline gains a requirement that Step 15 subtitle provider runtime remains optional Domain/provider enrichment and must not become a prerequisite for RSS, seasonal indexing, BT, online-rule, diagnostics, advanced captions, or native player implementations.

## Impact

- Affected code: `lib/src/domain/subtitle/`, `lib/src/provider/subtitle/`, subtitle cache contract consumers, public Dart barrel exports, focused subtitle provider runtime tests, runtime smoke checks, and validation scripts.
- Affected specs: new `phase3-subtitle-provider-runtime` plus deltas for `subtitle-provider-boundary`, `subtitle-provider-cache-contract`, `basic-subtitle-core`, and `repository-baseline`.
- Dependencies: no concrete Flutter subtitle UI, OpenSubtitles network client, ProviderGateway implementation change, SQLite/storage migration, advanced caption renderer, RSS engine behavior, seasonal indexer runtime, BT streaming, online-rule runtime, diagnostics center, MPV/VLC/native player binding, or external provider integration is introduced in this slice.
