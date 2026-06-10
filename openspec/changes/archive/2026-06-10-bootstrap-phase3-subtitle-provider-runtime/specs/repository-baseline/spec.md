## ADDED Requirements

### Requirement: Repository baseline SHALL keep subtitle-provider runtime optional and isolated
The repository baseline SHALL treat the Step 15 subtitle-provider runtime as optional Domain/provider enrichment that must not become a prerequisite for core playback, media library, video detail, RSS, seasonal indexer, BT, online-rule, diagnostics, advanced caption rendering, storage migration, or native-player implementation.

#### Scenario: Later slices are absent
- **WHEN** RSS engine runtime, seasonal indexer, BT streaming, online-rule runtime, diagnostics center, advanced caption rendering, storage implementations, and native-player adapters are not implemented
- **THEN** the subtitle-provider runtime can still search deterministic provider candidates, reuse subtitle cache contracts, retrieve subtitle files, and prepare basic parser handoff requests

### Requirement: Repository baseline SHALL validate Step 15 boundary terms
The repository baseline SHALL include validation for subtitle-provider runtime files that rejects later-phase and concrete implementation dependencies while allowing Provider subtitle, Domain subtitle discovery, cache contract, and basic subtitle parser handoff contracts.

#### Scenario: Boundary checker runs
- **WHEN** the Step 15 subtitle-provider runtime checker scans project files
- **THEN** forbidden dependencies on concrete UI, storage implementations, network clients, scraping, captcha automation, RSS, seasonal, BT, online-rule, diagnostics, advanced captions, MPV/VLC, or native-player bindings fail validation
