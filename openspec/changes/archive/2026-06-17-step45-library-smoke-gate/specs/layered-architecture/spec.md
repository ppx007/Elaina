## ADDED Requirements

### Requirement: Step 45 library smoke gate SHALL preserve UI ownership boundaries
Step 45 library smoke gate work SHALL provide non-UI runtime composition,
tests, checker tooling, and integration notes without adding or modifying
Flutter app shell, routes, pages, widgets, file picker UX, playback pages,
Windows runner files, or UI state composition.

#### Scenario: Library smoke gate is implemented
- **WHEN** Step 45 validates scan, import, detail, playback handoff, playback
  history, binding, and continue-watching replay
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  and UI-owned code may consume only Domain/runtime contracts rather than
  concrete smoke-gate internals, SQLite SQL, provider transports, native player
  bindings, streaming engines, or network implementations
