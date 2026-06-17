## ADDED Requirements

### Requirement: Step 40 ACG smoke gate SHALL preserve UI ownership boundaries
Step 40 ACG smoke gate work SHALL provide Domain/runtime composition, tests,
checkers, and integration notes without adding or modifying Flutter app shell,
routes, pages, widgets, login screens, metadata panels, subtitle panels,
danmaku panels, playback overlays, Windows runner files, or UI state
composition.

#### Scenario: ACG smoke gate is implemented
- **WHEN** Step 40 validates Bangumi, Dandanplay, subtitle provider, and
  playback metadata bridge composition
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  and UI-owned code may consume only Domain/Playback contracts rather than
  concrete provider clients or smoke-gate internals
