## ADDED Requirements

### Requirement: Fallback adapter runtime SHALL rebuild projection from store after restart
The system SHALL allow `FallbackAdapterRuntimeRestartProjection` to read stored active fallback configuration and strategy state from `FallbackAdapterStore` after a runtime restart, replaying the enabled state, selected candidate ID, and strategy state kind.

#### Scenario: Runtime replays stored fallback state after restart
- **WHEN** a new runtime is created via bootstrap after a previous runtime was disposed
- **THEN** the restart projection reads `activeConfiguration` and `latestStrategyState` from the store to restore fallback intent

### Requirement: Fallback adapter runtime SHALL persist fallback decisions on accepted requests
The system SHALL ensure that `selectFallback()`, `disable()`, `registerCandidate()`, and `reevaluateCapabilities()` operations persist their state and decision records to the fallback adapter store through the deterministic strategy before the runtime returns a typed projection.

#### Scenario: Runtime persists selection to store
- **WHEN** `selectFallback()` succeeds through the runtime
- **THEN** active configuration, selection history, and strategy state records are written to the fallback adapter store
