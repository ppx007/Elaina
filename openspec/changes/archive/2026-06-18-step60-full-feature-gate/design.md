## Context

The repository already has focused checker scripts for player core, player
smoke, ACG experience, library smoke, automation, BT streaming, advanced
playback, and diagnostics. Running them by hand is easy to drift. Step 60
should provide one explicit release-readiness command while preserving those
focused scripts as the source of truth for their domains.

## Goals / Non-Goals

**Goals:**

- Provide one full feature gate entry point.
- Reuse existing checkers and tests.
- Keep native player smoke explicit: optional by default, required only when
  requested.
- Keep UI/app-shell ownership external.

**Non-Goals:**

- No new checker framework or scheduler.
- No UI smoke automation.
- No remote services or native runner mutation.

## Decisions

- Use PowerShell because the existing Windows-oriented checker suite is already
  PowerShell based.
- Keep the script as orchestration only. It invokes existing commands and fails
  on their exit codes rather than reimplementing validation logic.
- Thread player smoke arguments through to `check_player_smoke_gate.ps1` so
  native smoke can be strict in release environments without breaking ordinary
  developer machines.

## Risks / Trade-offs

- The gate is slower than focused checks. Mitigation: keep focused scripts and
  document this gate as the full release-readiness check.
- Native smoke may be skipped when dependencies are absent. Mitigation:
  `-RequireNativeSmoke` makes absence a failure for release verification.
