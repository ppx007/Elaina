## 1. Layered Foundation Bootstrap

- [x] 1.1 Add a Phase 0 foundation runtime/bootstrap module under the Foundation layer that composes only Step 1-4 surfaces: layer manifest, StorageFoundation, ProviderGateway, and CacheInvalidationBus.
- [x] 1.2 Add deterministic layer-boundary metadata/checker contracts that identify forbidden imports from Flutter UI, playback adapters, provider implementations, streaming engines, concrete network clients, and platform services.
- [x] 1.3 Export only contract-safe bootstrap surfaces through the public Dart barrel without exposing concrete UI, playback, BT, online rule, WebView, DNS, proxy, database, or platform adapters.

## 2. Storage Foundation Composition

- [x] 2.1 Implement a deterministic `StorageFoundation` composition that wires existing local store contracts, including diagnostics, network policy, RSS automation, online rule runtime, WebView backfill, BT, virtual stream, scheduler, timeline, enhancement, AV sync, captions, and fallback stores.
- [x] 2.2 Provide test-safe deterministic metadata, blob, media cache, settings, media library, playback history, provider binding, subtitle cache, and RSS feed store scaffolding where interfaces currently lack a full composition implementation.
- [x] 2.3 Ensure storage bootstrap remains local-first and adapter-free, with no SQLite driver, remote storage, cloud sync, platform filesystem plugin, telemetry persistence, or mandatory startup migration dependency.

## 3. ProviderGateway and CacheInvalidation Runtime Wiring

- [x] 3.1 Implement deterministic ProviderGateway bootstrap behavior for provider registration, request key preservation, cache policy preservation, storage access, typed failure mapping, and supplied-loader execution without concrete HTTP/network dispatch.
- [x] 3.2 Add deterministic request de-duplication boundary scaffolding that preserves request outcomes for matching provider request keys without adding retry scheduling, provider-specific transport, or mutation beyond registration metadata.
- [x] 3.3 Add lifecycle-managed CacheInvalidationBus bootstrap wiring with deterministic close/dispose behavior and tests proving publishes after close are rejected.
- [x] 3.4 Ensure the bus remains payload-only and never triggers UI refresh, playback control, provider retry, BT command, network-policy mutation, or storage migration actions.

## 4. Validation and Documentation

- [x] 4.1 Add focused foundation runtime tests for bootstrap construction, layer boundary metadata, storage access, ProviderGateway request behavior, de-duplication boundaries, invalidation event delivery, and disposal.
- [x] 4.2 Extend runtime and boundary checker coverage for Phase 0 foundation bootstrap forbidden dependencies and contract-safe exports.
- [x] 4.3 Update project documentation to mark Step 1-4 implementation bootstrap as the next slice after Step 1-30 contract freeze.
- [x] 4.4 Run `openspec validate "bootstrap-phase0-foundation-runtime" --strict`, `openspec validate --all`, `dart analyze`, focused foundation runtime tests, runtime checker, and boundary checker scripts.


