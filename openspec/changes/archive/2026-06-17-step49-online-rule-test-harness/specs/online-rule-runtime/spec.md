## ADDED Requirements

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
