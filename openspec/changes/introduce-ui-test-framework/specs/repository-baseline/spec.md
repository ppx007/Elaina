## ADDED Requirements

### Requirement: Repository baseline SHALL expose stable UI element ids
Production UI SHALL declare reusable, named ids for navigation and high-churn
interactive surfaces that tests need to locate. These ids SHALL be centralized
outside test code and SHALL NOT contain test-only behavior.

#### Scenario: A test opens a primary shell page
- **WHEN** a widget or integration test navigates to home, tracking, local
  media library, downloads, RSS, settings, or diagnostics
- **THEN** it locates the sidebar target through the stable UI id instead of
  relying on localized text, icon order, or widget ancestry

#### Scenario: Dynamic UI targets are rendered
- **WHEN** search results, carousel items, or media-folder controls render with
  data-specific ids
- **THEN** production code uses a centralized helper to build the id string

### Requirement: Repository baseline SHALL provide an internal UI TestKit
High-churn UI tests SHALL use a project TestKit that provides app harnesses,
screen robots, and centralized finders for navigation and controls.

#### Scenario: A shell test needs default dependencies
- **WHEN** a test pumps the app shell
- **THEN** it uses `ElainaTestHarness` defaults for playback, media library,
  RSS, downloads, settings, diagnostics, and detail dependencies unless the
  scenario intentionally overrides one dependency

#### Scenario: A test performs user actions
- **WHEN** a test opens search, settings, downloads, RSS, media library, or a
  video detail surface
- **THEN** it uses a screen robot method for navigation/control actions and
  reserves text assertions for content that users must see

### Requirement: Repository baseline SHALL include official integration smoke
The repository SHALL include an official Flutter `integration_test` smoke that
boots the deterministic app harness on the desktop target and verifies primary
pages are reachable.

#### Scenario: Desktop smoke runs
- **WHEN** `flutter test integration_test/app_smoke_test.dart -d windows` runs
- **THEN** the app starts with deterministic dependencies and reaches home,
  settings, local media library, downloads, and RSS without real network or
  native-provider prerequisites

### Requirement: Repository baseline SHALL select changed tests declaratively
The changed-test gate SHALL read test-suite selection from a registry file
instead of hardcoding path rules inside the PowerShell script.

#### Scenario: Fast changed-test gate runs
- **WHEN** changed paths match registered suite triggers
- **THEN** the gate runs `dart analyze` plus the selected Dart or Flutter
  suites from `tools/test_suites.json`

#### Scenario: Module changed-test gate runs
- **WHEN** `-Scope Module` is selected
- **THEN** suites registered for module scope are eligible in addition to fast
  suites

#### Scenario: Full changed-test gate runs
- **WHEN** `-Scope Full` is selected
- **THEN** the gate delegates to the existing full feature gate
