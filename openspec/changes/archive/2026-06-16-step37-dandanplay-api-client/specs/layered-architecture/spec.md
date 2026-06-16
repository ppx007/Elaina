## ADDED Requirements

### Requirement: Step 37 Dandanplay API client SHALL preserve UI ownership boundaries
Step 37 concrete Dandanplay API client work SHALL provide Provider-layer
implementation, runtime injection, tests, checkers, and integration notes
without adding or modifying Flutter app shell, routes, pages, widgets, login
screens, danmaku panels, playback overlays, Windows runner files, or UI state
composition.

#### Scenario: Concrete Dandanplay client is implemented
- **WHEN** Step 37 adds real Dandanplay API dispatch support
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  and UI-owned code may consume only Domain/Provider contracts rather than
  concrete Dandanplay transport or API payload types
