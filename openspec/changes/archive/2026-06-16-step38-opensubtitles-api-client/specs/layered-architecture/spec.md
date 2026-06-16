## ADDED Requirements

### Requirement: Step 38 OpenSubtitles API client SHALL preserve UI ownership boundaries
Step 38 concrete OpenSubtitles provider work SHALL provide Provider-layer
implementation, tests, checkers, and integration notes without adding or
modifying Flutter app shell, routes, pages, widgets, subtitle search panels,
playback overlays, Windows runner files, or UI state composition.

#### Scenario: Concrete OpenSubtitles provider is implemented
- **WHEN** Step 38 adds real subtitle provider dispatch support
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  and UI-owned code may consume only Domain/Provider contracts rather than
  concrete OpenSubtitles transport or API payload types
