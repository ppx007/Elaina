## ADDED Requirements

### Requirement: Step 39 playback metadata bridge SHALL preserve UI ownership boundaries
Step 39 playback metadata bridge work SHALL provide Domain/runtime
composition, tests, checkers, and integration notes without adding or modifying
Flutter app shell, routes, pages, widgets, subtitle panels, danmaku panels,
playback overlays, Windows runner files, or UI state composition.

#### Scenario: Metadata bridge is implemented
- **WHEN** Step 39 connects subtitle and danmaku provider outputs to playback
  runtime projections
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  and UI-owned code may consume only Domain/Playback contracts rather than
  concrete provider clients or playback metadata bridge internals
