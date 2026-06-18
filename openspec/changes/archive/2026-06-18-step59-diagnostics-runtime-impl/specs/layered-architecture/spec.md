## ADDED Requirements

### Requirement: Step 59 SHALL keep diagnostics runtime implementation out of UI ownership
Step 59 SHALL implement local diagnostics collection/export support inside
Foundation-owned code and SHALL NOT add or modify Flutter UI, app shell,
diagnostics page, route, widget, file picker, video surface, `lib/main.dart`,
or `windows/**` files.

#### Scenario: Step 59 files are reviewed
- **WHEN** the Step 59 change is validated
- **THEN** diagnostics runtime implementation files are confined to Foundation
  diagnostics source, tests, tools, docs, and OpenSpec artifacts, with no
  UI/app-shell or runner ownership changes
