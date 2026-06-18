## ADDED Requirements

### Requirement: Repository baseline SHALL provide a Step 60 full feature gate
The repository baseline SHALL provide a single non-UI full feature gate command
that composes OpenSpec validation, Dart/Flutter analysis, full Flutter tests,
domain checker scripts, smoke gates, diagnostics checks, and optional native
player smoke without duplicating their internal validation logic.

#### Scenario: Full feature gate runs
- **WHEN** the Step 60 full feature gate is executed
- **THEN** it invokes the existing focused validators and fails on the first
  failing command rather than reporting a synthetic pass

#### Scenario: Native smoke is required
- **WHEN** the gate is executed with strict native player smoke enabled
- **THEN** missing libmpv or sample media dependencies are surfaced through the
  player smoke gate instead of being treated as release-ready

### Requirement: Full feature gate SHALL remain non-UI and local
The full feature gate SHALL NOT implement UI smoke automation, app-shell
behavior, remote telemetry, cloud upload, native runner mutation, or platform
installation side effects.

#### Scenario: Boundary checker scans full feature gate
- **WHEN** validation scans the Step 60 gate script and documentation
- **THEN** it confirms the gate is local validation orchestration only and does
  not modify UI, `lib/main.dart`, `windows/**`, global PATH, remote services, or
  native runner configuration
