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

#### Scenario: Dart runtime wrapper invokes a module
- **WHEN** `tools/runtime_check.dart --module <name>` or a compatibility
  `tools/*_runtime_check.dart` entrypoint runs
- **THEN** `Invoke-ModuleCheck.ps1` resolves the module through the registry
  before falling back to filename-derived legacy script lookup

#### Scenario: A new runtime check module is introduced
- **WHEN** a new module check is added
- **THEN** its registry entry is added before introducing optional public
  wrapper scripts, so coverage tests can validate the module mapping

### Requirement: Repository baseline SHALL keep compatibility tool entrypoints thin
Existing public PowerShell and Dart runtime-check entrypoints SHALL remain
available for humans and CI, but their implementation SHALL delegate to shared
module-check runners instead of containing repeated module-specific wrapper
classes or bespoke invocation code.

#### Scenario: Wrapper coverage is tested
- **WHEN** `test/tools` runs
- **THEN** every Dart runtime-check wrapper is verified against the module
  registry, its public check script, legacy script requirement, and contract
  files
