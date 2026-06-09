## ADDED Requirements

### Requirement: Video detail runtime MUST remain optional Domain enrichment
The repository baseline SHALL preserve the architecture rule that video detail runtime behavior is optional Domain/UI enrichment and MUST NOT become a prerequisite for core playback, player adapter availability, media scanning, subtitle provider runtime, RSS engine, seasonal indexing, BT streaming, online-rule runtime, network policy, storage migration, diagnostics, or native player implementations.

#### Scenario: Video detail runtime is unavailable
- **WHEN** detail metadata, provider bindings, continue-watching state, or follow state are unavailable
- **THEN** validation still proves core playback, provider runtimes, subtitle runtime, danmaku runtime, media-library contracts, and non-detail runtime slices can operate without video detail runtime dependencies

### Requirement: Video detail runtime MUST NOT bypass layer boundaries
The repository baseline SHALL require Step 13 video detail runtime validation to reject direct UI-to-provider access, UI-to-storage access, ProviderGateway internals in UI/detail surfaces, concrete Flutter page dependencies in Domain, media scanner ownership, RSS/seasonal ownership, BT ownership, online-rule ownership, network client ownership, and native player binding ownership.

#### Scenario: Boundary checker scans detail runtime
- **WHEN** Step 13 validation runs
- **THEN** forbidden cross-layer imports and later-phase implementation terms are rejected before the change is reported ready
