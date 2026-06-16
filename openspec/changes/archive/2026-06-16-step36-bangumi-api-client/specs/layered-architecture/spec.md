## ADDED Requirements

### Requirement: Step 36 Bangumi API client SHALL preserve UI ownership boundaries
Step 36 concrete Bangumi API client work SHALL provide Provider-layer
implementation, runtime injection, tests, checkers, and integration notes
without adding or modifying Flutter app shell, routes, pages, widgets, login
screens, detail pages, file picker UX, playback surfaces, Windows runner files,
or UI state composition.

#### Scenario: Concrete Bangumi client is implemented
- **WHEN** Step 36 adds real Bangumi API dispatch support
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  and UI-owned code may consume only Domain/Provider contracts rather than
  concrete Bangumi transport or API payload types
