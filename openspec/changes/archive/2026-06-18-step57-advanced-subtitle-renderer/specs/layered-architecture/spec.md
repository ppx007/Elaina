## ADDED Requirements

### Requirement: Step 57 SHALL keep concrete subtitle rendering out of UI ownership
Step 57 SHALL implement concrete subtitle application inside Playback-owned
binding code and SHALL NOT add or modify Flutter UI, app shell, route, settings
page, playback overlay, subtitle overlay, file picker, video surface,
`lib/main.dart`, or `windows/**` files.

#### Scenario: Step 57 files are reviewed
- **WHEN** the Step 57 change is validated
- **THEN** concrete subtitle renderer implementation files are confined to
  Playback source, tests, tools, docs, and OpenSpec artifacts, with no
  UI/app-shell ownership changes
