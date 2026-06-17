## ADDED Requirements

### Requirement: Step 49 online rule test harness SHALL preserve layer boundaries
Step 49 online rule test harness work SHALL provide Provider-layer validation
and supplied-document test reporting, tests, checker tooling, and integration
notes without adding or modifying Flutter app shell, routes, pages, widgets,
WebView screens, Windows runner files, network fetch implementations, BT
streaming, RSS auto-download, diagnostics actions, or UI state composition.

#### Scenario: Online rule test harness is implemented
- **WHEN** Step 49 adds the rule-source test harness
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  executable rule operations remain rejected by existing validation, and
  UI-owned code may consume only Provider/runtime contracts and harness reports
  rather than parser internals, crawler implementations, WebView handles,
  network clients, or source-specific scraper details
