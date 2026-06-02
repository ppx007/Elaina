## Context

Celesteria is a new cross-platform ACG player with a saved master rollout plan in `docs/celesteria-architecture-plan.md`. That plan explicitly recommends **Phase 0 / Step 1-4** as the first implementation slice: layered project boundaries, local storage foundation, `ProviderGateway`, and `CacheInvalidationBus`. There is no source tree yet, which means this change is not retrofitting an existing codebase; it is defining the first set of contracts that all future modules will inherit.

The main constraint is architectural, not feature-complete delivery. UI must not directly depend on MPV, VLC, Bangumi, Dandanplay, libtorrent, or yuc.wiki. External integrations must enter through Provider and Adapter boundaries. Future playback, RSS, provider auth, diagnostics, and cache coherence all depend on the foundation defined here.

## Goals / Non-Goals

**Goals:**
- Freeze the first coherent implementation boundary around Step 1-4.
- Define the allowed dependency directions across the 8 layers.
- Define baseline storage responsibilities and migration expectations before feature code exists.
- Define one shared gateway contract for all provider-facing network access.
- Define one event-driven invalidation contract for cache and read-model refresh.
- Produce an implementation-ready change boundary that later coding work can apply without revisiting the rollout scope.

**Non-Goals:**
- Building playback UI, player controls, or playback page interactions.
- Integrating MPV, VLC, Bangumi, Dandanplay, subtitle providers, RSS sources, BT streaming, or rule-source parsing.
- Defining final package names for every platform-specific implementation detail.
- Delivering a complete MVP beyond the Phase 0 foundation.

## Decisions

### 1. Model the first change as four separate capabilities aligned to Step 1-4

The architecture plan already divides the foundation into four steps with clear responsibilities. Representing them as four OpenSpec capabilities keeps the change decomposable and allows later implementation to progress incrementally while preserving a single proposal and task plan.

**Why this over one giant "foundation" capability?** A single spec would blur boundaries between layering, persistence, network governance, and invalidation. Separate capabilities make requirement ownership and later archive history much clearer.

### 2. Define dependency direction as a first-class contract, not just folder structure

The layered architecture capability will specify that each layer exposes interfaces and that upper layers depend only on lower-layer abstractions allowed by the architecture. This is stronger than creating directories because it makes forbidden dependencies testable and reviewable.

**Alternative considered:** only scaffold folders and leave dependency rules to code review. Rejected because that would let cross-layer shortcuts become the de facto architecture before enforcement exists.

### 3. Treat storage as a platform capability with explicit subdomains

The storage foundation will define SQLite metadata, blob cache, media cache, settings, and schema migration as part of one capability. These belong together because they provide durable state semantics for playback records, RSS entries, cache metadata, and diagnostics snapshots.

**Alternative considered:** defer storage until the first consumer feature appears. Rejected because every later feature would otherwise invent its own persistence shape and migration assumptions.

### 4. Centralize provider traffic through `ProviderGateway`

All provider-facing access will route through `ProviderGateway`, which owns request deduplication, rate limiting, retries, HTTP caching, negative caching, and normalized failure semantics. This prevents Bangumi, subtitle, RSS, and other provider integrations from each implementing their own partial network policy.

**Alternative considered:** let providers embed their own HTTP clients and adopt common utilities opportunistically. Rejected because it produces policy drift and makes diagnostics, throttling, and cache behavior inconsistent.

### 5. Use event-driven invalidation instead of direct cache mutation across modules

`CacheInvalidationBus` will define named business events such as `DanmakuPosted`, `BindingChanged`, and `ProviderAuthChanged`. Consumers subscribe and invalidate or refresh derived state based on event type. This keeps future detail, playback, RSS, and auth flows loosely coupled.

**Alternative considered:** direct invalidation calls between services. Rejected because it would create hidden dependencies and make later module growth harder to reason about.

### 6. Keep technology selection narrower than capability contracts

The spec and design will acknowledge SQLite as the planned metadata store because the architecture plan already names it, but the change will avoid overcommitting to framework-specific library glue where no code exists yet. The contract is what storage and gateway layers must do, not which concrete package every platform uses on day one.

## Risks / Trade-offs

- **[Risk] Foundation-only work has low visible product output** → **Mitigation:** keep the scope tightly bounded to Step 1-4 and produce clear follow-up tasks that unblock player-core work.
- **[Risk] Over-specifying implementation details before code exists** → **Mitigation:** specify behavioral contracts and dependency rules, not line-by-line implementation or premature library bindings.
- **[Risk] Under-specifying cross-layer boundaries leads to architecture drift** → **Mitigation:** make dependency direction, gateway usage, and invalidation flow explicit in the requirements.
- **[Risk] Storage scope balloons into full data modeling for every future feature** → **Mitigation:** define only baseline storage responsibilities and migration guarantees required by future modules.
- **[Risk] Gateway and invalidation contracts become generic abstractions with no business meaning** → **Mitigation:** anchor requirements in concrete future consumers named by the architecture plan, such as provider auth, Bangumi binding, RSS items, and diagnostics.

## Migration Plan

This is a greenfield change, so migration is sequencing rather than production rollout:

1. Create the project structure and layer contracts.
2. Establish storage contracts and migration scaffolding.
3. Introduce `ProviderGateway` as the mandatory route for provider-facing calls.
4. Introduce `CacheInvalidationBus` events and subscriber contract.
5. Only after these four parts are complete, start Phase 1 player-core work.

Rollback is trivial at this stage because no production system exists yet; the main safety mechanism is preserving tight scope and not advancing into player-core work before the foundation is complete.

## Open Questions

- Which Flutter/Dart persistence packages will back SQLite, blob cache, and settings in the first code pass?
- Which static analysis or package-boundary mechanism will enforce the allowed dependency directions?
- What concrete request interface will `ProviderGateway` expose for cacheable reads, mutations, retry policy, and failure classification?
- Will `CacheInvalidationBus` be in-process only for the first pass, or does the design need persistence/replay semantics for diagnostics later?
