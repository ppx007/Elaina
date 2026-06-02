## ADDED Requirements

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
