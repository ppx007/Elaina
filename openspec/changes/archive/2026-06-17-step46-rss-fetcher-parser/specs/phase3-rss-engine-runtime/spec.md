## ADDED Requirements

### Requirement: RSS engine runtime SHALL compose concrete RSS/Atom adapters
RSS engine runtime SHALL be able to compose the concrete Provider-layer HTTP
fetcher and RSS/Atom XML parsers through existing runtime bootstrap arguments.

#### Scenario: Runtime refreshes with concrete adapters
- **WHEN** the runtime registers a source and refreshes it with concrete feed
  fetch and parse adapters
- **THEN** accepted feed items, parser warnings, cursor validators, dedupe
  state, and update streams behave the same as deterministic feed contracts
  without requiring UI, live source management pages, seasonal indexing, RSS
  auto-download, BT, online rules, diagnostics, network-policy
  implementation, or native player bindings
