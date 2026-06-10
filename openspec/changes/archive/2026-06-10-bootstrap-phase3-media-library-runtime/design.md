## Context

The architecture plan places Phase 3 / Step 14 immediately after the completed Step 13 video detail page runtime. Step 14 is the media library: local scanning, playback history, provider binding state, and a library surface that can feed video detail and playback flows without requiring RSS, subtitle providers, seasonal indexing, BT, online rules, or concrete UI.

Current code already has many primitives in `lib/src/domain/media/media_library.dart`: local media identity, scan scope normalization, deterministic scanner, catalog repository, batch import, playback history store, provider binding store, and binding precedence. The missing piece is a runtime/bootstrap that composes those primitives into a coherent media-library state and action layer, plus tests and validation scripts proving the slice remains layer-isolated.

## Goals / Non-Goals

**Goals:**

- Provide a deterministic `MediaLibraryRuntime`/bootstrap entry point that composes scanner, catalog repository, batch import, playback history, provider binding store, playback source handoff, and cache invalidation bus.
- Provide explicit runtime state, snapshot, failure, result, query, and action values for scan/import/list/detail/remove/update/playback/binding/history flows.
- Reuse existing `MediaLibraryScanner`, `MediaLibraryCatalogRepository`, `MediaBatchImportContract`, `PlaybackHistoryStore`, `ProviderBindingStore`, and `PlaybackSourceHandoffContract` contracts instead of introducing parallel media models.
- Preserve Step 14 boundaries through focused tests, smoke checks, and PowerShell validation that forbid concrete UI, storage implementation, provider runtime, network, RSS, subtitle provider, seasonal, BT, online-rule, diagnostics, MPV/VLC, or native-player dependencies.
- Keep deterministic behavior suitable for contract validation before platform filesystem traversal or persistent database storage is implemented.

**Non-Goals:**

- No Flutter media library screen, widget tree, browsing UI, or platform picker integration.
- No concrete filesystem traversal, directory watcher, platform path API, WebDAV/SMB/Jellyfin connector, or native file permission flow.
- No SQLite schema migration, storage implementation, blob cache behavior, or database-backed repository.
- No provider metadata matching, Bangumi search queue, seasonal catalog behavior, subtitle provider, RSS engine, BT streaming, online rule, diagnostics center, network policy, MPV/VLC/native player, or external service integration.
- No changes to Step 13 video detail runtime beyond consuming stable media-library contracts later.

## Decisions

1. **Build Step 14 as a Domain media-library runtime, not a UI page.**
   - Rationale: the current repository validates Domain contracts first, and project rules require UI to consume Domain-facing surfaces rather than scanner, storage, provider, or native-player internals.
   - Alternative considered: implement a Flutter media-library page now. Rejected because Step 14 still needs runtime/state contracts and validation before concrete presentation.

2. **Reuse existing scanner/import/catalog/history/binding contracts.**
   - Rationale: `media_library.dart` already defines the core media values and deterministic in-memory stores. The runtime should compose them rather than split the model across runtime-local types.
   - Alternative considered: create separate runtime-specific scan item and catalog item types. Rejected because it would duplicate existing Domain media contracts and increase conversion complexity.

3. **Keep local scan deterministic and candidate-driven.**
   - Rationale: this project can validate scan scope normalization, accepted/excluded candidates, cancellation, watch events, and typed failures without platform filesystem traversal.
   - Alternative considered: add real filesystem walking. Rejected because Step 14 is a runtime contract slice and platform I/O belongs in a later adapter/storage implementation.

4. **Route playback through `PlaybackSourceHandoffContract`.**
   - Rationale: media library play actions should not construct `PlaybackSource` values directly or bypass playback capability checks. Existing handoff contracts already normalize local media identities and scan candidates.
   - Alternative considered: let the media runtime create local file playback sources directly. Rejected because it would couple media-library actions to playback implementation details.

5. **Publish cache invalidation events without owning persistence.**
   - Rationale: `CacheInvalidationBus` already has media-library, history, and binding events. Step 14 should publish deterministic events for runtime state changes while leaving storage durability to later persistence implementations.
   - Alternative considered: add a runtime-owned persistent cache. Rejected because it would force storage migration into this slice.

6. **Treat provider bindings as local media authority only.**
   - Rationale: user-confirmed bindings outrank automatic bindings in existing media contracts. Step 14 should expose and mutate binding state locally but not run metadata matching or remote progress sync.
   - Alternative considered: trigger Bangumi lookup/match from media import. Rejected because automatic matching belongs to seasonal/Bangumi matching slices, not local media runtime.

## Risks / Trade-offs

- **[Risk] Runtime grows into platform file scanning.** → Mitigation: tests and boundary checks forbid platform path APIs, filesystem traversal, storage implementation, network, and concrete UI dependencies.
- **[Risk] Media library duplicates video detail follow/continue state.** → Mitigation: keep history and binding as authoritative Domain media contracts consumed by both runtimes.
- **[Risk] Import deduplication misses edge cases.** → Mitigation: require tests for URI duplicates, fingerprint duplicates, URI/fingerprint conflicts, skipped duplicates, and failed candidates.
- **[Risk] Cache invalidation becomes too broad.** → Mitigation: publish existing `MediaLibraryItemChanged`, `HistoryRecorded`, and `BindingChanged` event types with local identifiers only.
- **[Risk] Step 14 bleeds into Step 15-17 work.** → Mitigation: explicitly forbid subtitle provider, RSS engine, seasonal indexer, yuc.wiki, provider matching queues, and auto-download behavior.

## Migration Plan

1. Add media-library runtime values, snapshot/result/failure types, query/action values, and a `MediaLibraryRuntime`/bootstrap composition entry point under `lib/src/domain/media/`.
2. Compose existing deterministic scanner, catalog repository, batch import, playback history store, provider binding store, playback handoff, and cache invalidation bus behind the runtime.
3. Add deterministic scan/import/catalog/history/binding/playback actions and observer snapshots.
4. Export safe media-library runtime surfaces through `lib/celesteria.dart`.
5. Add focused tests, a Dart smoke checker, and a PowerShell boundary checker that chains existing Phase 3 checks.
6. Run `openspec validate "bootstrap-phase3-media-library-runtime" --strict`, `openspec validate --all`, `dart analyze`, focused media-library runtime tests, media-library checker scripts, and existing detail/library, video detail, Bangumi, Dandanplay, subtitle, and danmaku smoke checks.

Rollback before archive is deleting the new runtime/test/tool files and removing this change directory. No persisted schema, storage migration, platform I/O, or external provider state is introduced.

## Open Questions

- Whether future concrete filesystem traversal should live in a platform adapter or a storage-backed scanner implementation should be decided when real I/O is introduced.
- Whether media-library UI should consume a Domain snapshot directly or a separate UI contract should be deferred until a concrete Flutter page slice.
- Whether automatic Bangumi matching should run after import remains out of scope until the seasonal/Bangumi matching queue slice.
