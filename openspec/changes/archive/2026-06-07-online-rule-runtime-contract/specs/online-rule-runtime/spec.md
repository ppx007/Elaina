## ADDED Requirements

### Requirement: Online rule runtime SHALL use typed validation and evaluation contracts
The system SHALL represent manifest registration, manifest validation, manifest refresh, page retrieval, target evaluation, unsupported operations, disabled state, and capability checks through typed outcomes and failures rather than nullable maps, thrown concrete parser exceptions, or implicit unsupported behavior.

#### Scenario: Required extraction fails
- **WHEN** a required operation for a target cannot produce its normalized output
- **THEN** the runtime reports a typed evaluation failure with source identity, target type, operation identity, and reason

### Requirement: Online rule runtime SHALL expose normalized target read models
The system SHALL expose search results, detail metadata, episode entries, and playable-source candidates as target-specific normalized read models derived from declarative extraction operations.

#### Scenario: Episode target is evaluated
- **WHEN** an episode page or section satisfies a declared episode target
- **THEN** the runtime returns normalized episode records without requiring detail or playable-source rules to execute in the same step

### Requirement: Online rule runtime SHALL preserve optional behavior
The system SHALL allow local playback, manual URL playback, BT virtual stream playback, RSS refresh, media-library browsing, and provider flows to continue when online rule sources are disabled, unsupported, invalid, or absent.

#### Scenario: Online rule source is disabled
- **WHEN** online rule evaluation is disabled for a source
- **THEN** the runtime reports a disabled outcome and does not request page retrieval or extraction work

### Requirement: Online rule runtime MUST reject executable rule operations
The system MUST reject or disable JavaScript, WASM, scriptlet, arbitrary code execution, unsupported selector syntax, and unsafe regex operations in the Step 27 baseline runtime.

#### Scenario: Manifest declares WASM extraction
- **WHEN** a manifest declares a WASM operation for extraction
- **THEN** validation records an unsupported-operation issue and the operation is not executed
