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

### Requirement: Online rule runtime SHALL support runtime acceptance layer
The system SHALL allow manifest validation and document evaluation to be consumed through a runtime facade that provides storage-backed projections, typed scoped outcomes, restart replay, and dispose/unavailable/capability gates instead of calling the deterministic runtime directly from UI or application flows.

#### Scenario: Runtime wraps deterministic evaluator with storage and projections
- **WHEN** the Step 27 runtime acceptance layer is implemented
- **THEN** manifest validation is consumed through OnlineRuleSourceRuntime.validate() which delegates to the deterministic runtime, persists results to OnlineRuleRuntimeStore, and returns a typed projection

### Requirement: Online rule runtime decisions SHALL propagate through invalidation bus
The system SHALL propagate online rule validation state changes, manifest changes, target evaluations, and unsupported operation recordings through the CacheInvalidationBus accepted at bootstrap construction so downstream consumers can refresh derived state.

#### Scenario: Runtime publishes validation events
- **WHEN** a manifest is validated through the runtime for a supported scope
- **THEN** OnlineRuleValidationStateChanged and OnlineRuleManifestChanged events are published to the cache invalidation bus

### Requirement: Online rule runtime SHALL evaluate supplied documents with bounded concrete extraction
The online rule runtime SHALL evaluate supplied document content with concrete
regex extraction, CSS selector subset extraction, and XPath subset extraction
instead of marker-style placeholder matching.

#### Scenario: CSS selector target is evaluated
- **WHEN** an operation declares a supported CSS selector and the supplied
  document contains a matching element
- **THEN** the runtime extracts the requested text or attribute value into the
  typed evaluation result without exposing raw selector internals to UI or
  playback layers

#### Scenario: XPath target is evaluated
- **WHEN** an operation declares a supported XPath subset expression and the
  supplied document contains a matching element
- **THEN** the runtime extracts the requested text or attribute value into the
  typed evaluation result

#### Scenario: Regex target is evaluated
- **WHEN** an operation declares a safe regex expression and the supplied
  document contains a match
- **THEN** the runtime extracts the first capture group when present, otherwise
  the whole match

### Requirement: Online rule runtime SHALL reject unsupported selector syntax
The online rule runtime SHALL validate unsupported CSS and XPath syntax as
typed `unsupportedSelector` issues rather than silently falling back, throwing
parser-specific exceptions, or executing arbitrary code.

#### Scenario: Unsupported selector is declared
- **WHEN** a manifest declares selector syntax outside the bounded Step 48 CSS
  or XPath subset
- **THEN** validation returns an unsupported-selector issue associated with the
  operation and evaluation does not execute that operation

### Requirement: Online rule runtime SHALL keep executable operations disabled
The Step 48 evaluator SHALL keep JavaScript, WASM, scriptlet, arbitrary code,
browser DOM execution, and unsafe regex operations outside the runtime.

#### Scenario: Executable operation is declared
- **WHEN** a manifest declares JavaScript, WASM, scriptlet, arbitrary code, or
  unsafe regex behavior
- **THEN** validation records a typed unsupported-operation issue and the
  supplied-document evaluator does not execute it

### Requirement: Online rule runtime SHALL provide a non-UI rule-source test harness
The online rule runtime SHALL provide a Provider-layer test harness that accepts
an online rule manifest and caller-supplied target documents, validates the
manifest once, evaluates each supplied document with the existing evaluator, and
returns a typed report.

#### Scenario: Rule source test plan succeeds
- **WHEN** a valid manifest and supplied documents for multiple targets are run
  through the harness
- **THEN** the report contains the validation result, one target report per
  supplied document, successful evaluation outcomes, and normalized target
  outputs without requiring UI, network fetch, WebView, or source-specific
  scraper behavior

### Requirement: Online rule test harness SHALL short-circuit invalid manifests
The test harness SHALL not evaluate target documents when manifest validation
fails.

#### Scenario: Manifest validation fails
- **WHEN** a manifest declares unsupported selector, JavaScript, WASM,
  scriptlet, arbitrary code, or unsafe regex operations
- **THEN** the harness returns a failed report containing validation issues and
  no target evaluation reports

### Requirement: Online rule test harness SHALL surface target failures without replacing runtime contracts
The test harness SHALL reuse existing online rule evaluation outcomes,
failures, warnings, and normalized output models instead of creating parallel
runtime failure semantics.

#### Scenario: Required target output is missing
- **WHEN** a supplied document does not produce a required output
- **THEN** the target report contains the typed evaluation failure from the
  online rule runtime

### Requirement: Online rule test harness SHALL participate in the automation smoke gate
The online rule test harness SHALL support a non-UI automation smoke path that
validates a supplied online rule manifest and evaluates caller-supplied target
documents into normalized outputs.

#### Scenario: Automation smoke gate validates rule-source output
- **WHEN** the automation smoke gate runs a valid online rule manifest and
  supplied search/detail documents through `OnlineRuleTestHarness`
- **THEN** the report succeeds with target reports and normalized outputs
  while still requiring no UI, live network fetch, WebView, captcha automation,
  JavaScript, WASM, source-specific scraper, RSS auto-download handoff, BT,
  diagnostics action, or native player behavior

