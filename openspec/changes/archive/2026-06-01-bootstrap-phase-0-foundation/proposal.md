## Why

Elaina is still a greenfield project, but its architecture plan already makes one thing explicit: starting from playback UI or a single provider integration would hard-code cross-layer dependencies too early and create rework across playback, RSS, metadata, and diagnostics. The first implementation slice needs to freeze the architectural foundation so later feature work lands on stable contracts instead of ad hoc glue.

## What Changes

- Establish the first executable change around **Phase 0 / Step 1-4** from the architecture plan.
- Define normative requirements for the 8-layer project boundary model so UI, Domain, Playback, Provider, Gateway, Storage, Streaming, and Network remain isolated by interface contracts.
- Define the storage foundation required for future playback records, RSS entries, provider state, cache metadata, and diagnostics snapshots.
- Define a shared `ProviderGateway` capability for request deduplication, rate limiting, retries, cache-aware fetches, and uniform failure semantics.
- Define a `CacheInvalidationBus` capability so cross-module state changes invalidate cached views through explicit events instead of direct coupling.

## Capabilities

### New Capabilities
- `layered-architecture`: Defines the mandatory 8-layer module boundary model and allowed dependency directions.
- `local-storage-foundation`: Defines the baseline storage contracts for SQLite, blob/media cache, settings, and schema migration.
- `provider-gateway`: Defines the shared gateway behavior that all external provider traffic must use.
- `cache-invalidation-bus`: Defines the event-driven cache invalidation mechanism used across modules.

### Modified Capabilities

None.

## Impact

- Affects initial project structure and package/module boundaries.
- Establishes persistent storage and migration contracts before any feature-specific code exists.
- Forces future Bangumi, Dandanplay, subtitle, RSS, and rule-source integrations to depend on shared gateway semantics instead of bespoke networking logic.
- Forces future detail page, playback page, RSS, provider auth, and binding flows to integrate through invalidation events rather than direct cache mutation.
