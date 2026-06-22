# Elaina

Elaina (code name 1017) is an end-side-first cross-platform ACG player planned around Flutter/Dart frontend contracts and native playback/download adapters.

## Current Baseline

- OpenSpec is the active workflow authority for proposal, apply, validation, and archive work.
- The Step 1-30 contract bootstrap has been archived into `openspec/changes/archive/` and synced into `openspec/specs/`.
- Dart contract scaffolding lives under `lib/` and is validated with `dart analyze` plus the Dart CLI in `tools/`.
- Trellis files remain in `.trellis/` as legacy context only; do not route new work through Trellis unless a future change explicitly re-enables it.

## Workflow

Use OpenSpec for new changes:

```powershell
openspec.cmd list --json
openspec.cmd new change "<change-name>"
openspec.cmd status --change "<change-name>" --json
openspec.cmd instructions apply --change "<change-name>" --json
openspec.cmd validate --all
openspec.cmd archive "<change-name>" -y
```

Use focused validation while iterating. Small changes should start with the
fast changed-path gate instead of a repository-wide Flutter test run:

```powershell
dart run tools\elaina_tool.dart check changed --scope Fast
```

Use the module scope when a change crosses related UI/domain/provider files:

```powershell
dart run tools\elaina_tool.dart check changed --scope Module
```

Tooling-only Dart tests intentionally live under `test/tools` and can run with
the Dart test runner:

```powershell
dart run tools\elaina_tool.dart check module --module runtime_check_base
```

Runtime check modules are registered in `tools\module_checks.json`. New modules
should add a registry entry first. The generic Dart entrypoint is:

```powershell
dart run tools\elaina_tool.dart check module --module bangumi_runtime
```

Project tests that import `flutter_test` require the Flutter test runner; do not
use repository-wide `dart test` as a full-project substitute. Run focused
Flutter tests by path during normal development:

```powershell
flutter test test\ui\hero_carousel_test.dart test\widget_test.dart
```

Run the full release-readiness gate before treating the current baseline as
complete. The full gate includes OpenSpec validation, analysis, full Flutter
tests, module checks, and the non-UI player smoke gate:

```powershell
dart run tools\elaina_tool.dart check full
```

Frontend implementation should start from the handoff document:

```text
docs/frontend-handoff.md
```

On Windows, `openspec.cmd` avoids PowerShell execution-policy blocking of `openspec.ps1`.
If `dart.bat` hangs in the Flutter shim because Git rejects the Flutter SDK checkout as
`dubious ownership`, validate with the direct SDK executable until the Flutter checkout is
added to Git `safe.directory`:

```powershell
& "D:\CodeWork\flutter_windows_3.44.0-stable\flutter\bin\cache\dart-sdk\bin\dart.exe" analyze lib test tools
```


## Phase 0 Foundation Runtime (Step 1-4 Bootstrap)

The Phase 0 foundation runtime bootstrap is now implemented:

- **`lib/src/foundation/foundation_bootstrap.dart`** - Single entry-point composing all Step 1-4 surfaces
- **`lib/src/foundation/foundation_runtime.dart`** - `FoundationRuntime` + `DeterministicProviderGateway`
- **`lib/src/foundation/deterministic_storage_foundation.dart`** - `DeterministicStorageFoundation` + 7 missing store scaffolds
- **`lib/src/foundation/layer_boundary_checker.dart`** - `LayerBoundaryChecker` for forbidden/required term validation

Run bootstrap validation:

```powershell
dart run tools\elaina_tool.dart check module --module phase0_foundation
dart run tools\elaina_tool.dart check module --module player_core
openspec.cmd validate "bootstrap-phase0-foundation-runtime" --strict
```

## Repository Policy

- Do not commit, push, configure remotes, or publish without an explicit user request.
- Create or update `.gitignore` before staging files.
- Preserve `openspec/`, `docs/`, `lib/`, `tools/`, root manifests, and agent instructions as project source of truth.
- Treat `.trellis/` as legacy context pending an explicit preservation or deletion decision.
