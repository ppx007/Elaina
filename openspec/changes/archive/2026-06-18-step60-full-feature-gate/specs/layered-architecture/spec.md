## ADDED Requirements

### Requirement: Step 60 SHALL keep full feature gate outside UI ownership
Step 60 SHALL add full regression and release-readiness validation tooling
without adding or modifying Flutter UI, app shell, diagnostics page, playback
page, routes, widgets, file picker, video surface, `lib/main.dart`, or
`windows/**` files.

#### Scenario: Step 60 files are reviewed
- **WHEN** the Step 60 change is validated
- **THEN** changed files are limited to tools, docs, tests, and OpenSpec
  artifacts, with no UI/app-shell or runner ownership changes
