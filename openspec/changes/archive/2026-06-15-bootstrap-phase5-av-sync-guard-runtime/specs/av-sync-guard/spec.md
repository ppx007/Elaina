## MODIFIED Requirements

### Requirement: AVSyncGuard SHALL use durable policy and state contracts
AVSyncGuard SHALL back drift thresholds, sample windows, health transitions, and degradation decisions with durable policy and state contracts that can be evaluated and restored without concrete renderer dependencies. The runtime acceptance layer SHALL wrap the deterministic guard with storage-backed projections, typed scoped outcomes, and restart replay so playback flows consume guard state through a stable runtime contract.

#### Scenario: Bootstrap guard interface is refined
- **WHEN** the Step 23 AV sync guard runtime is implemented
- **THEN** one-shot drift samples are evaluated through storage-safe policy/state records and typed outcomes rather than concrete MPV timing properties

#### Scenario: Runtime projects health and degradation from store
- **WHEN** the runtime reads latest health and degradation records from the guard store
- **THEN** the projection exposes the current health, latest drift, and latest degradation action without requiring an active deterministic guard instance

## MODIFIED Requirements

### Requirement: AVSyncGuard SHALL separate degradation decisions from adapter execution
AVSyncGuard SHALL emit deterministic degradation decisions as contract data while leaving concrete enhancement, caption, fallback, or renderer mutations to future adapter implementations. The runtime acceptance layer SHALL wrap degradation decisions in typed `AVSyncGuardRuntimeActionResult` outcomes so consuming code can inspect success/failure/availability states without handling concrete adapter exceptions.

#### Scenario: Runtime returns typed degradation outcome
- **WHEN** a degradation request is issued through the runtime for a supported scope
- **THEN** the runtime returns `AVSyncGuardRuntimeActionResult.success` containing the degradation projection on success or `AVSyncGuardRuntimeActionResult.failed` containing a typed failure on rejection
