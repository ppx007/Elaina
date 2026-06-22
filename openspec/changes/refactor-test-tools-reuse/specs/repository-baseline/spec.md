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
public check scripts, legacy scripts, Dart entrypoints, contracts, focused
tests, and required files.

#### Scenario: Dart runtime CLI invokes a module
- **WHEN** `tools/runtime_check.dart --module <name>` runs
- **THEN** `Invoke-ModuleCheck.ps1` resolves the module through the registry
  before falling back to filename-derived legacy script lookup

#### Scenario: A new runtime check module is introduced
- **WHEN** a new module check is added
- **THEN** its registry entry is added before introducing optional public
  wrapper scripts, so coverage tests can validate the module mapping

### Requirement: Repository baseline SHALL keep tool entrypoints consolidated
Existing public PowerShell check entrypoints SHALL remain available for humans
and CI, while Dart runtime checks SHALL use the generic
`tools/runtime_check.dart --module <name>` entrypoint instead of per-module
wrapper files.

#### Scenario: Tool coverage is tested
- **WHEN** `test/tools` runs
- **THEN** the generic Dart runtime-check entrypoint, module registry, public
  check scripts, legacy script requirements, and contract files are verified,
  and per-module Dart wrapper files are rejected
