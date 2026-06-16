## ADDED Requirements

### Requirement: Step 34 UI integration contract SHALL remain non-UI implementation work
Step 34 UI integration contract work SHALL provide stable source, lifecycle,
dispose, and error-handling contracts for the external UI model without adding
Flutter app shell, routes, pages, widgets, file picker UX, video surfaces, or
Windows runner implementation.

#### Scenario: Integration contract is implemented
- **WHEN** Step 34 integration guidance is added
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  while docs, tests, checkers, and OpenSpec specs define the external UI
  model's playback integration boundary
