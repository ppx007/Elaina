## 1. RED: Focused runtime tests

- [x] 1.1 Add `test/playback/av_sync_guard_runtime_test.dart` with failing imports for `AVSyncGuardBootstrap`, `AVSyncGuardRuntime`, `AVSyncGuardRuntimeProjection`, `AVSyncGuardRuntimeRestartProjection`, `AVSyncGuardRuntimeFailure`, `AVSyncGuardRuntimeFailureKind`, `AVSyncGuardRuntimeActionResult` — expect compile error (RED)
- [x] 1.2 Add RED test: initial snapshot for supported scope returns projection with stored health from seeded guard store — expectNoSuchMethodError
- [x] 1.3 Add RED test: ingestSample returns typed success outcome with health and drift — expectNoSuchMethodError
- [x] 1.4 Add RED test: requestDegradation returns typed success outcome with degradation action — expectNoSuchMethodError
- [x] 1.5 Add RED test: checkRecovery returns typed success on recovered drift — expectNoSuchMethodError
- [x] 1.6 Add RED test: unsupported scope ingest returns failure with capabilityUnsupported kind — expectNoSuchMethodError
- [x] 1.7 Add RED test: unavailable runtime rejects all operations — expectNoSuchMethodError
- [x] 1.8 Add RED test: disposed runtime rejects snapshot — expectNoSuchMethodError
- [x] 1.9 Add RED test: storage-visible invalidation events arrive after health transition and degradation — expectNoSuchMethodError
- [x] 1.10 Add RED test: restart projection replays stored health and latest degradation action — expectNoSuchMethodError

## 2. GREEN: Runtime implementation

- [x] 2.1 Add `lib/src/playback/av_sync_guard_runtime.dart` with `AVSyncGuardBootstrap`, `AVSyncGuardRuntime`, `AVSyncGuardRuntimeFailureKind`, `AVSyncGuardRuntimeFailure`, `AVSyncGuardRuntimeActionResultKind`, `AVSyncGuardRuntimeActionResult<T>`, `AVSyncGuardRuntimeProjection`, `AVSyncGuardRuntimeRestartProjection` — Playback layer
- [x] 2.2 Add `export 'src/playback/av_sync_guard_runtime.dart';` to `lib/celesteria.dart` — Playback/UI layer
- [x] 2.3 Run focused tests — expect all pass (GREEN)

## 3. Contract validation

- [x] 3.1 Run `test/playback/av_sync_guard_contract_test.dart` — expect existing contract tests pass
- [x] 3.2 Run `test/playback/video_enhancement_pipeline_runtime_test.dart` — expect prior tests unaffected
- [x] 3.3 Run `test/playback/av_sync_guard_runtime_test.dart` — expect new runtime tests pass
- [x] 3.4 Run all three test files together — expect 0 failures

## 4. Checker coverage

- [x] 4.1 Add `tools/av_sync_guard_runtime_check.dart` Dart smoke checker — Tools layer
- [x] 4.2 Add `tools/check_av_sync_guard_runtime.ps1` PowerShell boundary checker — Tools layer
- [x] 4.3 Run Dart smoke checker — expect exit 0
- [x] 4.4 Run PowerShell boundary checker — expect "AV sync guard runtime checks passed."

## 5. Validation gates

- [x] 5.1 Run focused Flutter tests — expect all pass
- [x] 5.2 Run `dart analyze` — expect no issues
- [x] 5.3 Run `openspec validate "bootstrap-phase5-av-sync-guard-runtime" --strict` — expect valid
- [x] 5.4 Run `openspec validate --all` — expect 0 failed

## 6. Scope guard and completion

- [x] 6.1 Scope guard: scan runtime, test, and checker for forbidden boundary terms (native, MPV, VLC, FFI, shader, renderer, diagnostics center, network policy, RSS, captions, fallback, Flutter widget imports) — expect no hits
- [x] 6.2 LSP diagnostics on `lib/src/playback/av_sync_guard_runtime.dart` and `tools/av_sync_guard_runtime_check.dart` — expect clean
- [x] 6.3 Mark all tasks complete — expect 25/25
