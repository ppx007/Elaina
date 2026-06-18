## MODIFIED Requirements

### Requirement: Online rule runtime SHALL evaluate supported extraction operations only
The system SHALL support declared CSS selector, XPath 1.0, and regex extraction
operations and MUST report unsupported operations instead of executing arbitrary
code or unsafe unbounded regex behavior.

#### Scenario: Manifest declares unsupported script execution
- **WHEN** a rule manifest declares JavaScript, WASM, scriptlet, or arbitrary code execution
- **THEN** the runtime rejects or disables that operation and reports a validation failure

#### Scenario: Manifest declares unsafe regex extraction
- **WHEN** a rule manifest declares a regex with nested unbounded quantifiers,
  repeated broad wildcards, or another rejected unsafe shape
- **THEN** validation records a typed `unboundedRegex` unsupported-operation
  issue and supplied-document evaluation does not execute that regex

### Requirement: Online rule runtime SHALL use typed validation and evaluation contracts
The system SHALL represent manifest registration, manifest validation, manifest
refresh, page retrieval, target evaluation, target normalization, unsupported
operations, disabled state, and capability checks through typed outcomes and
failures rather than nullable maps, thrown concrete parser exceptions, or
implicit unsupported behavior.

#### Scenario: Required extraction fails
- **WHEN** a required operation for a target cannot produce its normalized output
- **THEN** the runtime reports a typed evaluation failure with source identity,
  target type, operation identity, and reason

#### Scenario: Normalization fails after extraction
- **WHEN** extraction succeeds but a required normalized field is missing or a
  normalized URI is invalid
- **THEN** the runtime reports a typed target failure and does not throw a raw
  parser, URI, or state exception to harness or source-runtime callers
