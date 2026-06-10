## Why

Phase 3 / Step 13 video detail runtime is complete and archived, so the architecture plan's next slice is Phase 3 / Step 14: media library. Existing Domain contracts define local media identities, scan scopes, scan results, catalog repositories, batch imports, playback history, and provider bindings, but there is no deterministic runtime that composes those contracts into a usable media-library surface for local scan, import, listing, continue-watching, binding state, and playback handoff.

## What Changes

- Add a deterministic Phase 3 media library runtime/bootstrap that wires local media scanner contracts, catalog repository, batch import, playback history, provider binding store, playback source handoff, and cache invalidation behind Domain-facing surfaces.
- Add runtime result, snapshot, lifecycle, query, and action outcomes for scan/import/catalog/history/binding flows without introducing concrete filesystem traversal, database migrations, Flutter widgets, provider runtimes, network clients, RSS, subtitle provider, seasonal indexer, BT, online-rule, diagnostics, or native-player bindings.
- Add deterministic media-library actions for scan scope normalization, batch import, catalog list/detail, duplicate detection, continue-watching projection, binding precedence, remove/update behavior, and local playback handoff using existing Domain media and playback contracts.
- Add focused tests and smoke/boundary checks proving Step 14 remains a media-library runtime slice and does not expand into subtitle provider, RSS engine, seasonal indexer, BT streaming, online rule sources, storage implementation, concrete UI, ProviderGateway internals, or MPV/VLC/native player code.
- No breaking changes.

## Capabilities

### New Capabilities
- `phase3-media-library-runtime`: Deterministic runtime/bootstrap for media library scanning, import, catalog state, continue-watching, provider binding state, playback handoff, lifecycle snapshots, tests, and validation.

### Modified Capabilities
- `media-library-foundation`: Existing media-library contracts gain deterministic runtime, catalog-state projection, scan/import action, continue-watching, and binding-state requirements while remaining provider-, UI-, storage-implementation-, and native-player-neutral.
- `local-media-scanner-contract`: Local scanner contracts gain runtime consumption requirements for deterministic scan execution, cancellation, watch events, typed failures, and handoff-safe candidates without concrete filesystem traversal.
- `media-library-persistence-contract`: Persistence contracts gain deterministic runtime usage requirements for catalog import/list/update/remove, playback history projection, duplicate handling, and provider binding precedence without database migration implementation.
- `playback-source-handoff-contract`: Media-library play actions gain a requirement to route selected local media and scan candidates through existing handoff contracts instead of constructing playback sources in UI, storage, provider, scanner, or native-player code.
- `repository-baseline`: Repository baseline gains a requirement that Step 14 media library runtime remains optional Domain/runtime enrichment and must not become a prerequisite for subtitle provider, RSS, seasonal indexing, BT, online-rule, network, diagnostics, or native player implementations.

## Impact

- Affected code: `lib/src/domain/media/`, `lib/src/domain/playback/playback_source_handoff.dart` consumers, `lib/src/foundation/cache_invalidation/`, public Dart barrel exports, focused media-library runtime tests, runtime smoke checks, and validation scripts.
- Affected specs: new `phase3-media-library-runtime` plus deltas for `media-library-foundation`, `local-media-scanner-contract`, `media-library-persistence-contract`, `playback-source-handoff-contract`, and `repository-baseline`.
- Dependencies: no concrete Flutter media-library page, platform filesystem traversal, SQLite/storage migration, ProviderGateway implementation change, subtitle provider runtime, RSS engine behavior, seasonal indexer runtime, BT streaming, online-rule runtime, network policy, diagnostics center, MPV/VLC/native player binding, or external provider integration is introduced in this slice.
