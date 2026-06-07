# online-rule-runtime Specification

## Purpose
TBD - created by archiving change bootstrap-automation-extension-core. Update Purpose after archive.
## Requirements
### Requirement: Online rule runtime SHALL use declarative manifests
The system SHALL define online rule sources as versioned declarative manifests containing source identity, update metadata, selectors, XPath 1.0 expressions, regex extractors, target page types, and validation status.

#### Scenario: Rule manifest is loaded
- **WHEN** a rule source manifest is loaded
- **THEN** the runtime validates manifest identity, version, checksum metadata, and declared extraction operations before making it available

### Requirement: Online rule runtime SHALL evaluate supported extraction operations only
The system SHALL support declared CSS selector, XPath 1.0, and regex extraction operations and MUST report unsupported operations instead of executing arbitrary code.

#### Scenario: Manifest declares unsupported script execution
- **WHEN** a rule manifest declares JavaScript, WASM, scriptlet, or arbitrary code execution
- **THEN** the runtime rejects or disables that operation and reports a validation failure

### Requirement: Online rule runtime SHALL separate page types
The system SHALL model search, detail, episode, and playable-source extraction as separate rule targets with normalized outputs for each target type.

#### Scenario: Detail rule is evaluated
- **WHEN** a detail page rule is evaluated successfully
- **THEN** the runtime returns normalized detail metadata without requiring search, episode, or playback rules to run in the same step

### Requirement: Online rule runtime MUST use ProviderGateway for network access
Online rule fetches, manifest updates, and page retrieval MUST use ProviderGateway and network policy contracts rather than source-owned transport logic.

#### Scenario: Rule source fetches a page
- **WHEN** the runtime needs network content for a rule evaluation
- **THEN** the request is routed through ProviderGateway with the provider's network policy and normalized failure semantics

### Requirement: Online rule runtime MUST NOT be required for core playback
The system MUST ensure online rule parsing is optional and cannot become a prerequisite for local file playback, manual URL playback, BT virtual stream playback, or media-library operation.

#### Scenario: Online rules are unavailable
- **WHEN** no online rule runtime is available for the current environment
- **THEN** existing local playback, manual playback-source entry, and library flows continue through their existing contracts

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

