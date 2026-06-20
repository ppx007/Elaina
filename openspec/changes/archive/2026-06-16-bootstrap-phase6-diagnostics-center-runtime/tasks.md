## 1. RED Test

- [x] 1.1 Create `test/foundation/diagnostics_center_runtime_test.dart` with runtime scenarios for initial snapshot, schema registration, redacted event recording, query snapshot, local export descriptor, retention enforcement, capability recording, unsupported capability, unavailable runtime, disposed runtime, missing schema, invalidation events, and restart projection replay
- [x] 1.2 Verify RED tests fail on missing diagnostics runtime symbols before implementation

## 2. GREEN Implementation

- [x] 2.1 Create `lib/src/foundation/diagnostics/diagnostics_center_runtime.dart` with bootstrap, runtime, typed failure/action result types, projections, gates, persistence, redaction, and event publication
- [x] 2.2 Add barrel export `export 'src/foundation/diagnostics/diagnostics_center_runtime.dart';` in `lib/elaina.dart`
- [x] 2.3 Run focused runtime tests and confirm all pass

## 3. Contract Coverage

- [x] 3.1 Verify runtime failure mapping covers unsupported capability, unavailable, disposed, missing schema, record failure, snapshot failure, retention failure, and export failure cases
- [x] 3.2 Verify schema, event, snapshot, export, retention, and capability records are stored before invalidation events are published
- [x] 3.3 Verify redaction happens before event persistence and export description remains local
- [x] 3.4 Verify restart projection reads stored diagnostics state without invoking playback, provider, RSS, online rule, WebView, BT, network policy, UI, native, FFI, platform channel, telemetry, or cloud upload behavior

## 4. Validation Checkers

- [x] 4.1 Add `tools/diagnostics_center_runtime_check.dart` Dart smoke checker covering runtime happy path, failure gates, invalidation events, redaction, retention, export, and restart replay
- [x] 4.2 Add `tools/check_diagnostics_center_runtime.ps1` PowerShell boundary checker for required files, barrel export, smoke run, required terms, and forbidden Step 30 boundary terms
- [x] 4.3 Run Dart smoke checker and verify exit 0
- [x] 4.4 Run PowerShell boundary checker and verify passed output

## 5. Quality Gates

- [x] 5.1 Run focused Flutter tests for diagnostics center contract and runtime tests
- [x] 5.2 Run `dart analyze` and verify no new issues
- [x] 5.3 Run `openspec validate "bootstrap-phase6-diagnostics-center-runtime" --strict` and verify valid
- [x] 5.4 Run `openspec validate --all` and verify all pass

## 6. Scope and Completion

- [x] 6.1 Scope guard: scan runtime, test, and checker files for forbidden boundary terms (Flutter UI, playback control, provider mutation, RSS execution, online rule execution, WebView control, BT enqueue, network policy mutation, native, FFI, platform channel, remote telemetry, cloud upload, MPV/VLC/media-kit, captcha, yuc.wiki, libtorrent) and verify no leakage
- [x] 6.2 Mark all tasks complete in this file after implementation and validation
- [x] 6.3 Archive `bootstrap-phase6-diagnostics-center-runtime` and verify `openspec validate --all` passes after sync
