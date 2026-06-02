## 1. Layered architecture foundation

- [x] 1.1 Create the initial project/module layout for UI, Domain, Playback, Provider, Gateway, Storage, Streaming, and Network layers.
- [x] 1.2 Define and document allowed dependency directions so each layer exposes interfaces and forbidden cross-layer direct dependencies are blocked by convention or tooling.
- [x] 1.3 Add baseline contracts for Adapter / Provider / Profile / FeatureFlag extension points where the architecture plan requires future substitution.

## 2. Local storage foundation

- [x] 2.1 Define the initial SQLite metadata schema boundary for future playback records, RSS entries, provider state, and diagnostics snapshots.
- [x] 2.2 Establish blob cache, media cache, and settings storage responsibilities with clear ownership by the Storage layer.
- [x] 2.3 Add schema-version and migration scaffolding so later features can evolve storage without ad hoc upgrade logic.

## 3. Provider gateway foundation

- [x] 3.1 Define the `ProviderGateway` interface and request pipeline for provider-facing traffic in the Gateway layer.
- [x] 3.2 Implement or scaffold deduplication, required provider rate-policy registration, retry scheduling, HTTP cache hooks, and negative-cache behavior as shared gateway responsibilities.
- [x] 3.3 Define normalized failure semantics and provider registration points so future Bangumi, subtitle, RSS, and rule-source integrations reuse one governance path.

## 4. Cache invalidation foundation

- [x] 4.1 Define the `CacheInvalidationBus` contract and initial business event vocabulary, including binding, auth, and posting-related events.
- [x] 4.2 Define subscriber behavior for cache invalidation and derived-read refresh without direct cross-module mutation.
- [x] 4.3 Wire the invalidation contract into the foundation design so later detail page, playback page, RSS, and provider-auth flows extend by adding events instead of coupling services.

## 5. Foundation verification and readiness

- [x] 5.1 Validate that Phase 0 / Step 1-4 is complete before any Phase 1 playback-core task begins.
- [x] 5.2 Verify the resulting foundation still respects the architecture red lines: no UI-to-provider/player direct dependency and no provider-specific networking, cache, retry, rate-limit, or negative-cache implementation outside `ProviderGateway`.
- [x] 5.3 Prepare the next implementation change boundary for Phase 1 player core only after the foundation contracts are stable.
