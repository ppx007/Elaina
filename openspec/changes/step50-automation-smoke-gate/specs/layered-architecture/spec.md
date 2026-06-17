## ADDED Requirements

### Requirement: Step 50 automation smoke gate SHALL preserve layer boundaries
Step 50 automation smoke gate work SHALL provide non-UI composition tests,
checker tooling, and integration notes for the RSS refresh, seasonal feed flow,
and online rule test harness path without adding or modifying Flutter app
shell, routes, pages, widgets, WebView screens, Windows runner files, live
network source fetching, native player bindings, RSS auto-download handoff, BT
streaming, diagnostics actions, or UI state composition.

#### Scenario: Automation smoke gate is implemented
- **WHEN** Step 50 validates RSS refresh, seasonal catalog projection,
  Bangumi match queue projection, and supplied-document online rule test
  reporting
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  RSS concrete transport/parser details stay out of seasonal Domain files, and
  UI-owned code may consume only existing Domain/Provider runtime contracts
  rather than smoke-gate internals, WebView handles, crawler implementations,
  source-specific scrapers, BT engines, diagnostics actions, or native player
  dependencies
