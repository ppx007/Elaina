## ADDED Requirements

### Requirement: Repository baseline SHALL include VLC fallback adapter runtime layer
The system SHALL include `lib/src/playback/fallback_adapter_runtime.dart` as a Phase 5 Step 25 runtime acceptance layer that wraps `DeterministicPlaybackFallbackStrategy` with per-scope gate checks, typed `FallbackAdapterRuntimeActionResult<T>` outcomes, and snapshot/restart projections.

#### Scenario: Runtime file exists and exports bootstrap
- **WHEN** the codebase is inspected for Step 25 artifacts
- **THEN** `fallback_adapter_runtime.dart` contains `FallbackAdapterBootstrap`, `FallbackAdapterRuntime`, and projection types, and `celesteria.dart` exports the runtime

### Requirement: Repository baseline SHALL enforce VLC fallback adapter runtime boundary
The system SHALL enforce that `fallback_adapter_runtime.dart` does not import `player_adapter`, `playback_controller`, VLC-specific packages, native FFI, Flutter widgets, diagnostics center, RSS automation, online rule runtime, WebView, captions, network policy, or any out-of-slice dependency.

#### Scenario: Boundary validation checks runtime imports
- **WHEN** Step 25 boundary validation scans runtime imports
- **THEN** only `cache_invalidation_bus`, `fallback_adapter_storage_contracts`, `fallback_adapter`, and `capability_matrix` are imported
