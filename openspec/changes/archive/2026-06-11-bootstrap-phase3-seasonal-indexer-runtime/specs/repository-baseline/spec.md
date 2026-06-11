## ADDED Requirements

### Requirement: Repository baseline SHALL keep seasonal indexer runtime optional and isolated
The repository baseline SHALL treat the Step 17 seasonal indexer runtime as optional Domain/provider enrichment that must not become a prerequisite for RSS engine operation, RSS auto-download, BT streaming, online-rule runtime, diagnostics center, concrete UI, network implementation, storage migration, or native-player implementation.

#### Scenario: Later slices are absent
- **WHEN** RSS auto-download policy execution, BT streaming, online-rule runtime, diagnostics center, concrete network clients, concrete storage implementations, UI pages, and native-player adapters are not implemented
- **THEN** the seasonal indexer runtime can still consume deterministic RSS accepted items, normalize seasonal catalog entries, queue Bangumi match work, and preserve user-confirmed binding priority through existing contracts

### Requirement: Repository baseline SHALL validate Step 17 boundary terms
The repository baseline SHALL include validation for seasonal indexer runtime files that rejects later-phase and concrete implementation dependencies while allowing Domain seasonal, Domain RSS, provider Bangumi, provider result, cache invalidation, and seasonal storage contracts.

#### Scenario: Boundary checker runs
- **WHEN** the Step 17 seasonal indexer runtime checker scans project files
- **THEN** forbidden dependencies on concrete UI, concrete HTTP clients, network implementation, yuc.wiki-specific scraping, crawlers, RSS auto-download execution, BT task creation, online-rule parsing, diagnostics, MPV/VLC, or native-player bindings fail validation
