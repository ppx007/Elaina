# av-sync-guard-contract Specification

## Purpose
TBD - created by archiving change av-sync-guard-contract. Update Purpose after archive.
## Requirements
### Requirement: AV sync guard contract SHALL persist policy and guard state
The system SHALL define durable AV sync guard contracts for policy configuration, latest health state, sample history metadata, and degradation decision history without storing concrete MPV property handles, native plugin state, renderer callbacks, or platform adapter internals.

#### Scenario: Guard state survives restart
- **WHEN** AV sync policy, latest health, or degradation decisions are written to Storage
- **THEN** later Playback flows can restore guard state through Storage contracts without loading MPV, native plugin, FFI, diagnostics, or renderer-specific state

### Requirement: AV sync guard contract SHALL evaluate sustained drift windows
The system SHALL evaluate normalized AV sync samples against target, warning, red-line, and recovery thresholds using deterministic sample-window contracts rather than relying on a single concrete adapter callback.

#### Scenario: Sustained drift enters degraded health
- **WHEN** a sample window remains above the 120ms red-line threshold according to the active policy
- **THEN** AVSyncGuard returns a degraded health outcome with an explicit reason and selected degradation action

### Requirement: AV sync guard contract SHALL expose typed evaluation and degradation outcomes
The system SHALL define typed outcomes for sample evaluation, health transitions, and degradation requests without throwing concrete adapter exceptions or requiring native rendering implementations.

#### Scenario: Degradation decision is accepted
- **WHEN** sustained drift exceeds the red line and the active policy has an available ordered degradation action
- **THEN** the guard records a degradation decision and publishes an invalidation event without invoking MPV, VLC, FFI, shader compiler, diagnostics center, or platform renderer code

### Requirement: AV sync guard contract SHALL consume enhancement pressure as input data
The system SHALL consume video enhancement render-budget pressure and candidate degradation targets as AV sync input data while keeping AVSyncGuard responsible for drift policy and leaving concrete enhancement application to future adapters.

#### Scenario: Enhancement pressure contributes to degradation choice
- **WHEN** drift is degraded and the sample includes enhancement pressure above budget
- **THEN** the guard can choose an enhancement reduction or disablement action from the active policy without directly mutating the enhancement pipeline

### Requirement: AV sync guard contract SHALL publish sync invalidation events
The system SHALL publish cache invalidation events when AV sync samples are ingested, guard health transitions, degradation decisions are recorded, or guard state recovers.

#### Scenario: Guard health changes
- **WHEN** AVSyncGuard transitions from warning to degraded or from degraded back toward target
- **THEN** an AV sync invalidation event is published so playback surfaces and future diagnostics consumers can refresh derived state without direct cross-module mutation

### Requirement: AV sync guard contract MUST remain scoped to Step 23
The system MUST keep concrete MPV timing probes, libmpv/media-kit bindings, native renderer callbacks, VLC fallback selection, diagnostics center behavior, DNS/network policy, online source rules, RSS automation, WebView challenge handling, and Flutter rendering outside the AVSyncGuard contract slice.

#### Scenario: Phase 5 checker runs
- **WHEN** boundary checks scan Step 23 contracts
- **THEN** no concrete timing probe implementation, native plugin, FFI, VLC fallback, diagnostics center, network policy, automation extension, or Flutter widget dependency is required by the AV sync guard contract

