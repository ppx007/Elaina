## Why

The VLC fallback adapter contract layer (Step 25) defines how playback switches from a primary adapter to a secondary VLC adapter after compatible failures, but there is no runtime acceptance layer that wraps the deterministic strategy with per-scope gate checks, typed projection/restart semantics, and boundary enforcement. Without this layer, UI and domain surfaces cannot safely observe fallback state, restart replay, or capability diffs through the established runtime pattern.

## What Changes

- Add `FallbackAdapterBootstrap` that accepts a `FallbackAdapterStore`, unmodifiable per-scope `DeterministicPlaybackFallbackStrategy` map, unmodifiable per-scope `PlaybackCapabilityMatrix` map, and optional `CacheInvalidationBus`, with a `createRuntime()` factory.
- Add `FallbackAdapterRuntime` with gate checks (disposed, unavailable, missing scope, unsupported `fallbackAdapter` capability), typed `FallbackAdapterRuntimeActionResult<T>` outcomes, snapshot/restart projections, and 5 delegated operations (`registerCandidate`, `deregisterCandidate`, `selectFallback`, `disable`, `reevaluateCapabilities`) plus `dispose()`.
- Add `FallbackAdapterRuntimeFailureKind` with 11 values covering the standard trio (capabilityUnsupported, unavailable, disposed) and domain-specific failures (duplicateCandidate, candidateNotFound, incompatibleFailure, noCandidate, persistenceRejected, sourceUnsupported, disabled, selectionRejected).
- Add `FallbackAdapterRuntimeRestartProjection` that reads stored active configuration and strategy state for restart replay.
- Add `FallbackAdapterRuntimeProjection` combining in-memory latest outcomes with stored fallback configuration, strategy state, and selection history.
- Add validation checker coverage (Dart smoke checker + PowerShell boundary checker) enforcing that no native/VLC/FFI/renderer/shader/diagnostics/network/RSS/captions/Flutter UI dependencies leak into the runtime slice.

## Capabilities

### New Capabilities
- `phase5-vlc-fallback-adapter-runtime`: Runtime acceptance layer for VLC fallback adapter bootstrap, projection, restart replay, and boundary enforcement.

### Modified Capabilities
- `vlc-fallback-adapter`: Add runtime acceptance requirement — fallback strategy SHALL be wrapped by a runtime acceptance layer that gates operations and projects combined state.
- `vlc-fallback-adapter-contract`: Add runtime ActionResult requirement — contract outcomes SHALL be surfaceable through the runtime typed ActionResult pattern, and boundary enforcement SHALL reject out-of-slice dependencies.
- `cache-invalidation-bus`: Add runtime invalidation requirements — runtime SHALL publish fallback state transition and selection decision events on ingestion.
- `local-storage-foundation`: Add storage replay requirement — runtime SHALL rebuild projection from store after restart and persist fallback decisions.
- `repository-baseline`: Add Step 25 runtime baseline and boundary validation requirements.

## Impact

- New file: `lib/src/playback/fallback_adapter_runtime.dart` (runtime + bootstrap + projections + failure kinds)
- Modified: `lib/celesteria.dart` (add barrel export for runtime)
- New test: `test/playback/fallback_adapter_runtime_test.dart`
- New tools: `tools/fallback_adapter_runtime_check.dart`, `tools/check_fallback_adapter_runtime.ps1`
- New OpenSpec capability: `phase5-vlc-fallback-adapter-runtime`
- Delta specs: 5 modified capabilities + 1 new capability
