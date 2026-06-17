## ADDED Requirements

### Requirement: Step 48 online rule evaluator SHALL preserve layer boundaries
Step 48 online rule evaluator work SHALL provide Provider-layer supplied
document validation and evaluation, tests, checker tooling, and integration
notes without adding or modifying Flutter app shell, routes, pages, widgets,
WebView screens, Windows runner files, network fetch implementations, BT
streaming, RSS auto-download, diagnostics actions, or UI state composition.

#### Scenario: Online rule evaluator is implemented
- **WHEN** Step 48 adds concrete CSS, XPath, and regex supplied-document
  evaluation
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  executable rule operations remain rejected, and UI-owned code may consume only
  Provider/runtime contracts and projections rather than parser internals,
  crawler implementations, WebView handles, network clients, or source-specific
  scraper details
