## ADDED Requirements

### Requirement: Online rule runtime contract SHALL expose rule-source test reports
The online rule runtime contract SHALL expose test plan, supplied document,
target report, and run report models that allow UI-owned rule-source test
screens to preview validation and evaluation results without depending on
parser internals.

#### Scenario: UI-owned rule test page previews a source
- **WHEN** UI-owned code needs to preview a rule source against sample
  documents
- **THEN** it consumes typed harness reports rather than importing parser
  internals, concrete network clients, WebView handles, crawler code, or
  source-specific scrapers

### Requirement: Online rule test reports SHALL preserve existing output models
Online rule test reports SHALL carry `OnlineRuleEvaluationOutcome` and
`OnlineRuleNormalizedOutput` values from the existing runtime contracts rather
than defining separate map-only result structures.

#### Scenario: Search target report is read
- **WHEN** a search target succeeds during a harness run
- **THEN** the target report exposes the existing normalized search output
  model for consumers
