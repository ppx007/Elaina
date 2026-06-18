## ADDED Requirements

### Requirement: Step 55 BT streaming smoke gate SHALL preserve layer boundaries
Step 55 BT streaming smoke gate work SHALL provide non-UI composition tests,
checker tooling, and integration notes for the BT task, virtual stream, byte
serving, and priority application path without adding or modifying Flutter app
shell, routes, pages, widgets, file picker UX, playback pages, Windows runner
files, native player bindings, HTTP/range servers, network policy
implementations, diagnostics actions, RSS automation, or UI state composition.

#### Scenario: BT streaming smoke gate runs without UI ownership
- **WHEN** Step 55 validates the BT streaming path
- **THEN** it composes only Streaming-layer contracts, concrete Streaming
  adapters, storage contracts, and smoke tooling, while leaving `lib/src/ui/**`,
  `lib/main.dart`, and `windows/**` untouched
