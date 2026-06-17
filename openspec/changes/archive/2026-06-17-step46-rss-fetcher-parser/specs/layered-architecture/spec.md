## ADDED Requirements

### Requirement: Step 46 RSS fetch/parser SHALL preserve UI ownership boundaries
Step 46 concrete RSS fetch/parser work SHALL provide Provider-layer feed
adapters, tests, checker tooling, and integration notes without adding or
modifying Flutter app shell, routes, RSS pages, widgets, Windows runner files,
or UI state composition.

#### Scenario: RSS fetch/parser is implemented
- **WHEN** Step 46 adds concrete HTTP feed fetching and RSS/Atom parsing
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  `dart:io` and XML parser imports stay out of Domain RSS runtime files, and
  UI-owned code may consume only Domain/runtime contracts rather than concrete
  transport/parser internals
