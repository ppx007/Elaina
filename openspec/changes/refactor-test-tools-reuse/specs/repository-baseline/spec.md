## ADDED Requirements

### Requirement: Repository baseline SHALL centralize runtime test fakes
Runtime, provider, and UI tests SHALL share reusable fake implementations for
common provider gateways, Bangumi providers/transports, cache invalidation
buses, playback handoff recorders, tracking providers, login controllers, and
UI hosts instead of copying private implementations into each high-level test
file.

#### Scenario: Bangumi provider contract grows
- **WHEN** a Bangumi provider method is added
- **THEN** focused tests update the shared Bangumi fake once and keep
  scenario-specific data in each test file

#### Scenario: UI test needs an app host
- **WHEN** a widget or shell test needs the Elaina theme host
- **THEN** it uses the shared UI test host instead of declaring a private
  MaterialApp/ElainaTheme wrapper

### Requirement: Repository baseline SHALL register module checks declaratively
Runtime check modules SHALL be declared in a registry that maps module names to
contracts, focused tests, required files, dependency checks, and boundary term
checks.

#### Scenario: Dart runtime CLI invokes a module
- **WHEN** `dart run tools/elaina_tool.dart check module --module <name>` runs
- **THEN** the Dart module runner resolves the module through
  `tools/module_checks.json` and executes only registry-declared checks

#### Scenario: A new runtime check module is introduced
- **WHEN** a new module check is added
- **THEN** its registry entry is added before depending on it from another
  module or the full gate

### Requirement: Repository baseline SHALL keep tool entrypoints consolidated
Active repository tooling SHALL use `tools/elaina_tool.dart` instead of tracked
PowerShell scripts or per-module Dart wrapper files.

#### Scenario: Tool coverage is tested
- **WHEN** `test/tools` runs
- **THEN** the Dart CLI, module registry, changed-test selector, Windows
  release packager, contract files, and absence of tracked PowerShell scripts
  are verified
