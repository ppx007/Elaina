## ADDED Requirements

### Requirement: Video enhancement pipeline SHALL use durable profile contracts
The video enhancement pipeline SHALL back declarative scaler, HDR, deband, and Anime4K-style profile intent with durable profile contracts that can be evaluated, applied, disabled, and restored without concrete renderer dependencies.

#### Scenario: Bootstrap profile intent is refined
- **WHEN** the Step 22 video enhancement pipeline contract is implemented
- **THEN** bootstrap profile intent is represented by storage-safe profile records and typed pipeline outcomes rather than concrete MPV shader options

### Requirement: Video enhancement pipeline SHALL separate budget handoff from sync policy
The video enhancement pipeline SHALL expose render-budget pressure and degradation targets as contract data while leaving A/V drift policy ordering and red-line degradation decisions to AVSyncGuard.

#### Scenario: Render budget pressure is reported
- **WHEN** the active enhancement profile is estimated to exceed frame budget
- **THEN** the pipeline reports pressure and a candidate lower profile or disabled state without deciding AVSyncGuard drift policy
