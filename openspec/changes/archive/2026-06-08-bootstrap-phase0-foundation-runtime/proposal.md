## Why

Elaina has completed the Step 1-30 contract bootstrap, including the Phase 6 diagnostics freeze, but the repository still needs a formal Phase 0 runtime foundation slice that turns Step 1-4 contracts into executable, reusable bootstrap scaffolding. This change starts implementation in the architecture-prescribed order: layer manifest first, then storage foundation, ProviderGateway, and CacheInvalidationBus.

## What Changes

- Add a foundation runtime/bootstrap contract that composes the Step 1-4 services without introducing UI, playback adapter, online source, BT engine, or platform implementation dependencies.
- Define a deterministic layer-boundary manifest/checker surface that keeps UI, Domain, Playback, Provider, Gateway, Storage, Streaming, and Network isolated at runtime bootstrap time.
- Add local-first storage foundation bootstrap scaffolding that exposes existing deterministic stores through a single `StorageFoundation` implementation suitable for tests and early runtime wiring.
- Add ProviderGateway bootstrap scaffolding for provider registration, request key preservation, de-duplication boundaries, cache-policy preservation, typed failure mapping, and storage access without concrete HTTP clients.
- Add CacheInvalidationBus bootstrap wiring so Step 1-4 services can publish/observe invalidation events through one lifecycle-managed bus.
- Add focused runtime/tests/checkers that prove local media, provider gateway, storage, and invalidation foundations can be composed without crossing layer boundaries.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `layered-architecture`: Add requirements for an executable Phase 0 foundation bootstrap that composes only Step 1-4 layers and preserves 8-layer isolation.
- `local-storage-foundation`: Add requirements for a deterministic `StorageFoundation` composition that exposes existing local stores through one bootstrap surface without concrete database adapters.
- `provider-gateway`: Add requirements for deterministic ProviderGateway bootstrap behavior covering registration, request key preservation, de-duplication boundaries, typed failures, and storage access without concrete network dispatch.
- `cache-invalidation-bus`: Add requirements for lifecycle-managed invalidation bus bootstrap wiring across foundation services.

## Impact

- Affected code: `lib/src/foundation/`, `lib/elaina.dart`, runtime checker scripts, focused tests, and OpenSpec specs for Step 1-4 foundation capabilities.
- No Flutter UI, concrete MPV/VLC/libtorrent/HTTP/DNS/database adapters, online rule execution, WebView automation, or platform services are introduced.
- This change should provide the implementation base that later Phase 1 playback core work can depend on without reopening Phase 6 extension contracts.
