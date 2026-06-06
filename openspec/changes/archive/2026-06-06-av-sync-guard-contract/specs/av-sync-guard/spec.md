## ADDED Requirements

### Requirement: AVSyncGuard SHALL use durable policy and state contracts
AVSyncGuard SHALL back drift thresholds, sample windows, health transitions, and degradation decisions with durable policy and state contracts that can be evaluated and restored without concrete renderer dependencies.

#### Scenario: Bootstrap guard interface is refined
- **WHEN** the Step 23 AV sync guard contract is implemented
- **THEN** one-shot drift samples are evaluated through storage-safe policy/state records and typed outcomes rather than concrete MPV timing properties

### Requirement: AVSyncGuard SHALL separate degradation decisions from adapter execution
AVSyncGuard SHALL emit deterministic degradation decisions as contract data while leaving concrete enhancement, caption, fallback, or renderer mutations to future adapter implementations.

#### Scenario: Red-line drift requests degradation
- **WHEN** sustained A/V drift exceeds the active red-line policy
- **THEN** the guard selects the next ordered degradation action without directly invoking VideoEnhancementPipeline, caption rendering, VLC fallback, diagnostics center, or platform renderer code
