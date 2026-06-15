# phase5-advanced-caption-rendering-runtime Specification

## Purpose
Step 24 runtime acceptance layer for advanced caption rendering. Wraps DeterministicAdvancedCaptionRenderer with bootstrap, scoped gate, typed action results, projection, and restart replay.

## Requirements

### Requirement: Advanced caption rendering runtime bootstrap SHALL create scoped runtimes
The system SHALL provide `AdvancedCaptionRuntimeBootstrap` that accepts a caption store, per-scope renderer map, per-scope capabilities, optional cache invalidation bus, and creates `AdvancedCaptionRuntime` instances for declared scopes.

#### Scenario: Bootstrap creates runtime for supported scope
- **WHEN** `AdvancedCaptionRuntimeBootstrap` is constructed with renderer and capability maps for scope `adapter-1`
- **THEN** `createRuntime()` returns an `AdvancedCaptionRuntime` that can evaluate, render, disable, and accept degradation for `adapter-1`

### Requirement: Advanced caption rendering runtime SHALL gate operations by state
The system SHALL check disposed, unavailable, missing scope, and unsupported capability before any caption operation and return typed failures.

#### Scenario: Disposed runtime rejects operations
- **WHEN** `AdvancedCaptionRuntime.dispose()` has been called
- **THEN** all subsequent operations return `AdvancedCaptionRuntimeFailureKind.disposed`

#### Scenario: Unsupported capability scope rejects operations
- **WHEN** the capability matrix does not support any advanced caption capability for a scope
- **THEN** operations on that scope return `AdvancedCaptionRuntimeFailureKind.capabilityUnsupported`

### Requirement: Advanced caption rendering runtime SHALL project combined state
The system SHALL provide `AdvancedCaptionRuntimeProjection` combining in-memory latest report, active profile, renderer state, and dual subtitle selection from both store and in-memory sources.

#### Scenario: Snapshot reads active profile and renderer state
- **WHEN** `snapshot(scopeId)` is called on a supported scope with seeded active profile and evaluated renderer state
- **THEN** the projection contains active profile ID, renderer state kind, and latest evaluation report

### Requirement: Advanced caption rendering runtime SHALL replay stored state on restart
The system SHALL provide `AdvancedCaptionRuntimeRestartProjection` that reads active profile, latest renderer state, and dual subtitle selection exclusively from the caption store.

#### Scenario: Restart projection reads from store
- **WHEN** a runtime is created for a scope with stored active profile `ac-p1` and stored renderer state `applied`
- **THEN** `AdvancedCaptionRuntimeRestartProjection` reports `activeProfileId: ac-p1` and `latestRendererState: applied`

### Requirement: Advanced caption rendering runtime MUST remain scoped to Step 24
The system MUST keep concrete Flutter widgets, GPU rendering, native plugins, FFI, VLC fallback, diagnostics center, RSS, WebView, network policy, and AV sync guard policy logic outside the advanced caption rendering runtime slice.

#### Scenario: Boundary validation
- **WHEN** boundary checks scan Step 24 runtime code
- **THEN** no concrete renderer, native plugin, FFI, VLC fallback, diagnostics center, Flutter widget, or out-of-scope Phase 6 dependency is found
