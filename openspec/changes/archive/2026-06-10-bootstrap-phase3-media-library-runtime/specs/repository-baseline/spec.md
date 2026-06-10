## ADDED Requirements

### Requirement: Repository baseline SHALL keep media-library runtime optional and isolated
The repository baseline SHALL treat the Step 14 media-library runtime as optional Domain/runtime enrichment that must not become a prerequisite for core playback, video detail, subtitle provider, RSS, seasonal indexer, BT, online-rule, network, diagnostics, storage migration, or native-player implementation.

#### Scenario: Later slices are absent
- **WHEN** subtitle providers, RSS engine, seasonal indexer, BT streaming, online-rule runtime, diagnostics center, network policy, and native-player adapters are not implemented
- **THEN** the media-library runtime can still scan deterministic candidates, import catalog state, expose history/bindings, and route local playback through handoff contracts

### Requirement: Repository baseline SHALL validate Step 14 boundary terms
The repository baseline SHALL include validation for media-library runtime files that rejects later-phase and concrete implementation dependencies while allowing Domain media, cache invalidation, and playback handoff contracts.

#### Scenario: Boundary checker runs
- **WHEN** the Step 14 media-library runtime checker scans project files
- **THEN** forbidden dependencies on concrete UI, ProviderGateway internals, storage implementations, subtitle provider, RSS, seasonal, BT, online-rule, network, diagnostics, MPV/VLC, or native-player bindings fail validation
