## ADDED Requirements

### Requirement: RSS engine runtime SHALL participate in the automation smoke gate
The RSS engine runtime SHALL support a non-UI smoke path that composes concrete
RSS fetch/parse adapters through existing bootstrap arguments and exposes
accepted feed items to downstream seasonal flow validation.

#### Scenario: Automation smoke gate refreshes a feed source
- **WHEN** the automation smoke gate registers and refreshes a feed source
  through the Step 46 fetcher/parser and RSS runtime bootstrap
- **THEN** the refresh succeeds, accepted feed items are produced, cursor
  request metadata remains observable, and RSS runtime behavior remains
  source-neutral without requiring UI, live source pages, RSS auto-download,
  BT, online rule internals, diagnostics actions, or native player behavior
