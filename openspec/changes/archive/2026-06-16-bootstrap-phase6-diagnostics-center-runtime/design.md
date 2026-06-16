## Context

Step 30 closes the Phase 6 extension runtime series. The diagnostics center contract already defines typed event schemas, redacted local event recording, deterministic query/snapshot scaffolding, retention outcomes, local export descriptors, and read-only boundaries. Storage contracts already provide deterministic persistence for schemas, events, snapshots, export requests/outcomes, retention state, and capability records. Cache invalidation events for diagnostics mutations already exist.

Adjacent Phase 6 runtimes use the same acceptance pattern: a bootstrap composes contracts and optional bus, a runtime exposes typed action results and projections, operations gate disposed/unavailable/unsupported states, state is persisted before events are published, and restart projections read from storage.

## Goals / Non-Goals

**Goals:**
- Provide a minimal `DiagnosticsCenterRuntimeBootstrap` and `DiagnosticsCenterRuntime` over existing diagnostics contracts.
- Return typed `DiagnosticsCenterRuntimeActionResult<T>` values for all runtime operations.
- Persist schemas, redacted events, snapshots, export requests/outcomes, retention state, and capability records through `DiagnosticsStore` before publishing invalidation events.
- Expose `DiagnosticsCenterRuntimeProjection` and `DiagnosticsCenterRuntimeRestartProjection` from store-backed state.
- Preserve read-only local diagnostics semantics and redaction before persistence/export.
- Add focused tests and smoke/boundary checkers.

**Non-Goals:**
- No remote telemetry, cloud upload, crash reporting client, analytics client, or network transport.
- No playback start/stop/pause/resume, provider mutation, feed retry, online rule execution, network policy mutation, WebView control, or BT task enqueue.
- No Flutter UI, native plugin, FFI, platform channel, MPV/VLC/media-kit, captcha, yuc.wiki, or libtorrent behavior.
- No clock parameter on bootstrap.
- No rewrite of existing deterministic diagnostics center or storage contracts.

## Decisions

**D1: Runtime wraps existing contracts only.** `DiagnosticsCenterRuntimeBootstrap` accepts `DiagnosticsStore`, `DiagnosticsEventRegistry`, `DiagnosticsRetentionPolicy`, `DiagnosticsRedactionPolicy`, `DiagnosticsCapabilityMatrix`, and optional `CacheInvalidationBus`. It creates a `DeterministicDiagnosticsCenter` internally and stores only through `DiagnosticsStore`.

**D2: Store-first event publication.** Runtime operations write the relevant storage record before publishing the corresponding existing diagnostics cache invalidation event. This matches Steps 27-29 and makes projections observable through storage before invalidation consumers run.

**D3: Runtime projections are storage-backed.** `snapshot()` reads stored schemas, filtered events, snapshots, latest export outcome, latest retention state, and capability state from `DiagnosticsStore`. It does not invoke external diagnostics upload or lifecycle actions.

**D4: Bootstrap has no clock parameter.** Runtime timestamps use `DateTime.now().toUtc()` at the operation boundary, matching adjacent Phase 6 runtime decisions and avoiding a public test-only clock API.

**D5: Redaction remains delegated to the existing deterministic center.** `recordEvent()` calls `DeterministicDiagnosticsCenter.record()` to enforce schema registration, required payload keys, capability gates, and redaction; the runtime then persists the redacted event record.

## Risks / Trade-offs

- [Runtime has several operations] -> Keep each operation a thin acceptance wrapper over existing contracts; no new diagnostics domain model.
- [Projection can grow too broad] -> Limit projection to latest stored records and query result counts needed for restart acceptance.
- [Boundary checker can self-trigger on forbidden terms] -> Build forbidden terms from split strings or skip the checker file itself where needed.
