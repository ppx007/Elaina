## ADDED Requirements

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
