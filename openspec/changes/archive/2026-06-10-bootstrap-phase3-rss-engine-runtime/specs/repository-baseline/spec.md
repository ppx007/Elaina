## ADDED Requirements

### Requirement: Repository baseline SHALL keep RSS engine runtime optional and isolated
The repository baseline SHALL treat the Step 16 RSS engine runtime as optional Domain/provider enrichment that must not become a prerequisite for seasonal indexer, RSS auto-download, BT streaming, online-rule runtime, diagnostics center, concrete UI, network implementation, storage migration, or native-player implementation.

#### Scenario: Later consumers are absent
- **WHEN** seasonal indexer runtime, RSS auto-download policy execution, BT streaming, online-rule runtime, diagnostics center, concrete network clients, concrete storage implementations, and native-player adapters are not implemented
- **THEN** the RSS engine runtime can still register deterministic feed sources, project due refreshes, refresh through feed contracts, persist accepted items, preserve cursor metadata, and emit accepted feed updates

### Requirement: Repository baseline SHALL validate Step 16 boundary terms
The repository baseline SHALL include validation for RSS engine runtime files that rejects later-phase and concrete implementation dependencies while allowing Domain RSS, Provider RSS, ProviderGateway result, and RSS feed storage contracts.

#### Scenario: Boundary checker runs
- **WHEN** the Step 16 RSS engine runtime checker scans project files
- **THEN** forbidden dependencies on concrete UI, concrete HTTP clients, network implementation, yuc.wiki-specific scraping, seasonal runtime, Bangumi match workers, RSS auto-download execution, BT task creation, online-rule parsing, diagnostics, MPV/VLC, or native-player bindings fail validation
