## 1. Domain Media Library Runtime

- [x] 1.1 Add media-library runtime result, failure, snapshot, observer, query, action, and lifecycle value objects under `lib/src/domain/media/` with deterministic disposed/unavailable behavior.
- [x] 1.2 Implement a `MediaLibraryRuntime` or `MediaLibraryBootstrap` composition entry point that wires `MediaLibraryScanner`, `MediaLibraryCatalogRepository`, `MediaBatchImportContract`, `PlaybackHistoryStore`, `ProviderBindingStore`, `PlaybackSourceHandoffContract`, and `CacheInvalidationBus`.
- [x] 1.3 Add deterministic catalog state projection that combines `MediaLibraryItem`, `ContinueWatchingState`, and strongest `ProviderBinding` values without provider-specific, UI-specific, storage-specific, or playback-specific models.
- [x] 1.4 Implement deterministic scan actions that normalize `MediaScanScope`, expose scan events, report typed scan failures, support cancellation/watch semantics, and avoid concrete filesystem traversal or platform path APIs.
- [x] 1.5 Implement deterministic import actions that persist accepted `MediaScanCandidate` values through `MediaBatchImportContract`, report imported/skipped/failed outcomes, and preserve URI/fingerprint duplicate behavior.
- [x] 1.6 Implement catalog list/detail/update/remove/count actions through `MediaLibraryCatalogRepository` with normalized success/ignored/unavailable/failed outcomes.
- [x] 1.7 Implement playback history and provider binding actions through `PlaybackHistoryStore` and `ProviderBindingStore`, preserving user-confirmed binding precedence over automatic bindings.
- [x] 1.8 Route catalog-item and scan-candidate playback actions through `PlaybackSourceHandoffContract` with explicit success/unavailable/unsupported outcomes.

## 2. Cache Invalidation, Exports, and Boundaries

- [x] 2.1 Publish existing cache invalidation events for imported, updated, removed, history-recorded, and binding-changed media state without introducing storage migrations or persistent runtime caches.
- [x] 2.2 Keep media-library runtime files provider-neutral and ensure they do not import concrete Flutter widgets, ProviderGateway internals, storage implementations, subtitle provider, RSS, seasonal indexer, BT, online-rule, network policy, diagnostics, MPV/VLC, or native-player bindings.
- [x] 2.3 Export only safe media-library runtime and contract surfaces through `lib/celesteria.dart` without exporting concrete Flutter media-library pages or storage implementations.
- [x] 2.4 Preserve existing Phase 3 detail/library/seasonal checker behavior while extending validation for the Step 14 media-library runtime slice.

## 3. Tests and Validation

- [x] 3.1 Add focused media-library runtime tests for scan scope normalization, accepted/excluded candidates, scan watch events, cancellation, typed scan failures, and runtime lifecycle snapshots.
- [x] 3.2 Add import/catalog tests for imported items, skipped URI duplicates, skipped fingerprint duplicates, duplicate conflicts, list pagination, unbound filtering, update/remove/count behavior, and immutable result surfaces.
- [x] 3.3 Add history/binding/playback action tests for continue-watching ordering, playback history recording, user-confirmed binding precedence, automatic binding preservation, successful local handoff, unsupported handoff, missing media, and disposed behavior.
- [x] 3.4 Add boundary tests or script checks proving media-library runtime does not own concrete filesystem traversal, storage migration, provider metadata matching, subtitle provider, RSS, seasonal indexer, BT, online-rule, network, diagnostics, UI widgets, or native player behavior.
- [x] 3.5 Add `tools/media_library_runtime_check.dart` smoke validation covering runtime scan/import/catalog state, continue-watching, binding precedence, playback handoff, and existing video detail/Phase 2 smoke checks.
- [x] 3.6 Add `tools/check_media_library_runtime.ps1` boundary validation that chains `check_video_detail_runtime.ps1` and rejects forbidden Step 15+ / Phase 4+ / concrete UI / provider internals / storage implementation / native-player dependencies in Step 14 runtime files.
- [x] 3.7 Run `openspec validate "bootstrap-phase3-media-library-runtime" --strict`, `openspec validate --all`, `dart analyze`, focused media-library runtime tests, media-library checker scripts, and existing detail/library, video detail, Bangumi, Dandanplay, subtitle, and danmaku runtime smoke checks.
