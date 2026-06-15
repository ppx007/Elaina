# phase5-vlc-fallback-adapter-runtime Specification

## Purpose
VLC fallback adapter runtime acceptance layer for Phase 5 Step 25. Wraps DeterministicPlaybackFallbackStrategy with per-scope gate checks, typed ActionResult outcomes, and snapshot/restart projections.
## Requirements
### Requirement: VLC fallback adapter runtime SHALL provide bootstrap acceptance layer
The system SHALL define a `FallbackAdapterBootstrap` that accepts a `FallbackAdapterStore`, unmodifiable per-scope `DeterministicPlaybackFallbackStrategy` map, unmodifiable per-scope `PlaybackCapabilityMatrix` map, and optional `CacheInvalidationBus`, with a `createRuntime()` factory returning a `FallbackAdapterRuntime`.

#### Scenario: Bootstrap creates a scoped runtime
- **WHEN** `FallbackAdapterBootstrap` is constructed with a store, strategy map, and capability map
- **THEN** `createRuntime()` returns a `FallbackAdapterRuntime` that gates operations by scope

### Requirement: VLC fallback adapter runtime SHALL gate operations by runtime state
The system SHALL gate all `FallbackAdapterRuntime` operations through a 4-step cascade: disposed check, unavailable check, missing scope check, and unsupported `fallbackAdapter` capability check.

#### Scenario: Disposed runtime rejects all operations
- **WHEN** `dispose()` has been called on the runtime
- **THEN** all subsequent operations return `FallbackAdapterRuntimeActionResult` with kind `disposed`

### Requirement: VLC fallback adapter runtime SHALL expose typed runtime outcomes
The system SHALL wrap all 5 strategy methods plus `snapshot()` through `FallbackAdapterRuntimeActionResult<T>` with success/failed/unavailable/disposed variants and `FallbackAdapterRuntimeFailureKind` with 11 values.

#### Scenario: Unsupported scope returns capabilityUnsupported
- **WHEN** a scope lacks `PlaybackCapability.fallbackAdapter` support
- **THEN** the runtime returns a failed result with `FallbackAdapterRuntimeFailureKind.capabilityUnsupported`

### Requirement: VLC fallback adapter runtime SHALL project combined state
The system SHALL provide `FallbackAdapterRuntimeProjection` combining in-memory latest outcomes with stored active fallback configuration, strategy state, and selection history, and `FallbackAdapterRuntimeRestartProjection` reading stored configuration and strategy state for restart replay.

#### Scenario: Projection after selection shows stored state
- **WHEN** a fallback selection succeeds and state is persisted to the store
- **THEN** `snapshot()` returns a projection reflecting the stored active configuration and strategy state

### Requirement: VLC fallback adapter runtime MUST remain boundary-clean
The system MUST NOT import VLC packages, native plugins, FFI, media-kit/libmpv bridges, platform player implementations, PlayerAdapter invocations, Flutter widgets, diagnostics center, RSS automation, online rule runtime, WebView, captions, network policy, or any Phase 6 concern within the runtime slice.

#### Scenario: Boundary checker scans runtime
- **WHEN** Phase 5 boundary checks scan the fallback adapter runtime
- **THEN** no VLC binding, native fallback, UI widget, PlayerAdapter import, or cross-domain dependency is present
