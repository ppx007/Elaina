## ADDED Requirements

### Requirement: Step 58 SHALL keep VLC fallback implementation out of UI ownership
Step 58 SHALL implement VLC fallback adapter core behavior inside
Playback-owned code and SHALL NOT add or modify Flutter UI, app shell, route,
settings page, fallback status display, playback overlay, file picker, video
surface, `lib/main.dart`, or `windows/**` files.

#### Scenario: Step 58 files are reviewed
- **WHEN** the Step 58 change is validated
- **THEN** concrete VLC fallback implementation files are confined to Playback
  source, tests, tools, docs, and OpenSpec artifacts, with no UI/app-shell or
  runner ownership changes
