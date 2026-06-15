# phase5-av-sync-guard-runtime Specification

## Purpose
TBD - created by archiving change bootstrap-phase5-av-sync-guard-runtime. Update Purpose after archive.
## Requirements
### Requirement: AV sync guard runtime SHALL provide bootstrap acceptance layer
The system SHALL define `AVSyncGuardBootstrap` that accepts a guard store, per-scope deterministic guard maps, per-scope capability matrices, optional cache invalidation bus, and injected clock to produce `AVSyncGuardRuntime` instances via `createRuntime()`.

#### Scenario: Bootstrap creates runtime with guard store and capabilities
- **WHEN** `AVSyncGuardBootstrap` is constructed with a guard store, scope-to-guard map, and scope-to-capability map
- **THEN** calling `createRuntime()` returns an `AVSyncGuardRuntime` that delegates to the per-scope deterministic guard

### Requirement: AV sync guard runtime SHALL provide typed scoped projections
The system SHALL expose `AVSyncGuardRuntimeProjection` that combines current in-memory health, latest drift, latest degradation action, and sample window metadata with stored health history to produce a restart-safe projection.

#### Scenario: Snapshot reads health and degradation from store after restart
- **WHEN** a runtime is created for a scope that has stored health and degradation records
- **THEN** `snapshot()` returns a projection reflecting the stored health and latest degradation action without requiring in-memory sample ingestion

### Requirement: AV sync guard runtime SHALL provide restart replay projection
The system SHALL define `AVSyncGuardRuntimeRestartProjection` that reads the latest health and latest degradation action from storage so restart flows can restore guard state without re-ingesting samples.

#### Scenario: Restart projection replays health and degradation
- **WHEN** a runtime is created for a scope with existing stored health and degradation records
- **THEN** the restart projection exposes the stored health kind and latest degradation action

### Requirement: AV sync guard runtime SHALL gate disposed unavailable and unsupported states
The system SHALL gate all operations (`snapshot`, `ingestSample`, `requestDegradation`, `checkRecovery`) against disposed, unavailable, and unsupported-capability states, returning typed `AVSyncGuardRuntimeFailure` outcomes.

#### Scenario: Disposed runtime rejects snapshot
- **WHEN** `dispose()` has been called on the runtime
- **THEN** `snapshot()` returns a disposed failure outcome

#### Scenario: Unavailable runtime rejects ingestion
- **WHEN** the runtime was constructed with `AVSyncGuardRuntime.unavailable()`
- **THEN** `ingestSample()` returns an unavailable failure outcome

### Requirement: AV sync guard runtime MUST remain scoped to Step 23
The system MUST keep concrete MPV timing probes, libmpv/media-kit bindings, native renderer callbacks, VLC fallback selection, diagnostics center behavior, DNS/network policy, online source rules, RSS automation, WebView challenge handling, and Flutter rendering outside the AV sync guard runtime slice.

#### Scenario: Boundary checker rejects out-of-scope dependencies
- **WHEN** boundary checks scan Step 23 runtime, test, and checker files
- **THEN** no concrete timing probe, native plugin, FFI binding, VLC fallback, diagnostics center, network policy, or Flutter widget import is found
