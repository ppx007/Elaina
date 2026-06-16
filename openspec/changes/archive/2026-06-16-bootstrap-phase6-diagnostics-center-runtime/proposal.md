## Why

The diagnostics center already has typed deterministic contracts, storage contracts, and cache invalidation events, but it lacks the Phase 6 runtime acceptance layer used by the adjacent runtime slices. Step 30 needs a minimal bootstrap/runtime wrapper so diagnostics state can be recorded, projected, replayed, retained, and exported through typed outcomes without gaining control authority over other layers.

## What Changes

- Add `DiagnosticsCenterRuntimeBootstrap` to compose an existing `DiagnosticsStore`, `DiagnosticsEventRegistry`, `DiagnosticsRetentionPolicy`, `DiagnosticsRedactionPolicy`, `DiagnosticsCapabilityMatrix`, and optional `CacheInvalidationBus` into a runtime. No clock parameter.
- Add `DiagnosticsCenterRuntime` with `recordSchema`, `recordEvent`, `querySnapshot`, `enforceRetention`, `describeLocalExport`, `recordCapability`, `snapshot`, and `dispose` operations returning typed action results.
- Add runtime projections and restart projections that read schema, event, snapshot, export, retention, and capability state from storage.
- Add tests and validation checkers for Step 30 runtime behavior, boundary control, barrel export, smoke execution, and OpenSpec validation.
- Keep diagnostics read-only: no playback control, provider mutation, feed retry, network policy mutation, BT task enqueue, UI, native, FFI, platform channel, remote telemetry, or cloud upload behavior.

## Capabilities

### New Capabilities
- `phase6-diagnostics-center-runtime`: Runtime acceptance layer for diagnostics center bootstrap, typed outcomes, store-backed projections, restart replay, retention/export descriptors, redaction, and capability gates.

### Modified Capabilities
- `diagnostics-center`: Add runtime acceptance behavior over existing diagnostics center contracts while preserving read-only local diagnostics semantics.
- `diagnostics-center-contract`: Add runtime-level typed outcome, projection, redaction, retention, and export acceptance requirements.
- `cache-invalidation-bus`: Add diagnostics runtime event publication requirements using existing diagnostics invalidation events.
- `local-storage-foundation`: Add runtime replay requirements over existing diagnostics storage contracts.
- `repository-baseline`: Add Step 30 diagnostics center runtime acceptance boundary.

## Impact

- New runtime file: `lib/src/foundation/diagnostics/diagnostics_center_runtime.dart`
- Modified barrel: `lib/celesteria.dart`
- New focused test: `test/foundation/diagnostics_center_runtime_test.dart`
- New tools: `tools/diagnostics_center_runtime_check.dart`, `tools/check_diagnostics_center_runtime.ps1`
- OpenSpec deltas for Step 30 runtime capability and touched specs
- No changes to existing deterministic diagnostics center or diagnostics storage contracts unless a compiler-level integration issue requires a minimal import/export adjustment
