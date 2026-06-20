## ADDED Requirements

### Requirement: Diagnostics UI SHALL render system telemetry
The diagnostics page SHALL show the current capability matrix checklist, active memory usage, and AV sync guard offset reports.

#### Scenario: Display telemetry state
- **WHEN** the diagnostics page is opened
- **THEN** it displays a list of all capabilities indicating support status
- **AND** displays the latest AV sync drift values from [AVSyncGuard](file:///D:/CodeWork/elaina/lib/src/playback/av_sync_guard.dart)

### Requirement: Diagnostics UI SHALL list timeline events
The diagnostics page SHALL list system events and warning logs chronologically in a scrollable table.

#### Scenario: Render timeline events logs
- **WHEN** the user selects the timeline log view tab
- **THEN** the UI renders a table of recent events, timestamps, and details retrieved from [DiagnosticsCenterRuntime](file:///D:/CodeWork/elaina/lib/src/foundation/diagnostics/diagnostics_center_runtime.dart)
