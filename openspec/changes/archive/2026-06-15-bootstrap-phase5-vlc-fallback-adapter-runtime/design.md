## Context

The VLC fallback adapter contract layer (Step 25) defines `PlaybackFallbackStrategy` with 5 methods (`register`, `deregister`, `selectFallback`, `disable`, `reevaluateCapabilities`), `DeterministicPlaybackFallbackStrategy` with store persistence, 6 typed outcome types, and `FallbackAdapterStore` for durable fallback state. Steps 22-24 established a runtime acceptance pattern: Bootstrap wraps unmodifiable maps, Runtime gates operations (disposed/unavailable/missing scope/unsupported capability), typed `ActionResult<T>` wraps all returns, Projection/RestartProjection combine in-memory and stored state.

## Goals / Non-Goals

**Goals:**
- Add `FallbackAdapterBootstrap` and `FallbackAdapterRuntime` following the established pattern
- Wrap all 5 strategy methods plus `snapshot()` and `dispose()` behind typed `FallbackAdapterRuntimeActionResult<T>` outcomes
- Support restart replay from stored active configuration and strategy state
- Enforce boundary: no VLC-specific, native, FFI, renderer, shader, diagnostics, network, RSS, captions, or Flutter UI imports in runtime
- Provide Dart smoke checker and PowerShell boundary checker coverage

**Non-Goals:**
- AVSyncGuard policy integration (Step 23 owns that boundary)
- Native VLC adapter implementation ( Phase 6 concern)
- Concrete PlayerAdapter invocation (runtime only passes candidates by value)
- UI rendering of fallback state
- Diagnostics center integration

## Decisions

**D1: Bootstrap pattern matches Steps 22-24.** `FallbackAdapterBootstrap` accepts `FallbackAdapterStore`, unmodifiable `strategyByScope` map, unmodifiable `capabilitiesByScope` map, optional `CacheInvalidationBus`, and `createRuntime()` factory. This is identical to the established pattern.

**D2: Gate checks follow 4-step cascade.** `_gate(scopeId)` checks disposed -> unavailable -> missing scope -> unsupported `PlaybackCapability.fallbackAdapter`. Identical to Steps 22-24.

**D3: 11 failure kinds preserve domain specificity.** The fallback domain has more failure paths than previous steps. Each maps to a specific contract failure: `capabilityUnsupported`/`unavailable`/`disposed` (standard) + `duplicateCandidate`/`candidateNotFound`/`incompatibleFailure`/`noCandidate`/`persistenceRejected`/`sourceUnsupported`/`disabled`/`selectionRejected` (domain). Collapsing loses information that callers use for UI decisions.

**D4: `deregisterCandidate` returns `ActionResult<Projection>`** not raw `bool`. Consistent with every other runtime method. The contract returns bool; the runtime wraps the removal result in a typed projection.

**D5: RestartProjection reads from stored active configuration and strategy state.** After restart, replays `enabled`, `selectedCandidateId`, and current `StoredFallbackStrategyStateKind` from the `FallbackAdapterStore`. No clock at runtime/bootstrap layer.

## Risks / Trade-offs

- [11 failure kinds is higher than Steps 22-24 (3-6)] -> Each maps to a specific contract failure; callers need the distinction. Accept the higher count.
- [`deregisterCandidate` breaks symmetry with contract `deregister()` returning `bool`] -> Runtime pattern consistency outweighs contract symmetry. Accept.
- [5 delegate methods + snapshot + dispose = 7 operations, more than Steps 22-24] -> The fallback strategy interface has more methods. Accept the complexity.
- [`FallbackAdapterCandidate` contains a `PlayerAdapter` field] -> Runtime receives candidates by value, does NOT invoke adapter methods. The checker forbids `PlayerAdapter` in runtime imports.
