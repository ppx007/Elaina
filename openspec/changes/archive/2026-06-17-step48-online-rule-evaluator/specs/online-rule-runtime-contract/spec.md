## ADDED Requirements

### Requirement: Online rule runtime contract SHALL expose concrete document-evaluation semantics
The online rule runtime contract SHALL define supplied-document evaluation as a
Provider-layer operation over declarative extraction operations, with bounded
CSS selector, XPath, and regex behavior returning typed values, warnings, and
failures.

#### Scenario: Rule source screens consume evaluation results
- **WHEN** UI-owned rule-source screens need to preview online rule output
- **THEN** they consume typed validation and evaluation outcomes from the
  online rule runtime contract instead of importing parser, WebView, crawler,
  or source-specific implementation details

### Requirement: Online rule runtime contract MUST normalize unsupported selector failures
The contract MUST represent selector syntax outside the supported Step 48
subset as `UnsupportedOnlineOperationKind.unsupportedSelector`.

#### Scenario: Selector validation fails
- **WHEN** CSS or XPath syntax is outside the supported subset
- **THEN** the validation issue exposes the operation identity, a typed
  unsupported-selector kind, and a human-readable reason
