## 1. RED: Focused runtime tests

- [x] 1.1 Create `test/playback/fallback_adapter_runtime_test.dart` with initial snapshot test that reads stored active configuration and strategy state from seeded store
- [x] 1.2 Add `registerCandidate` test verifying typed success projection with stored candidate and registration invalidation event
- [x] 1.3 Add `deregisterCandidate` test verifying typed success projection after candidate removal
- [x] 1.4 Add `selectFallback` test verifying typed success projection with selected candidate ID, hidden capabilities, strategy state, and invalidation events
- [x] 1.5 Add `disable` test verifying typed success projection with disabled strategy state and invalidation events
- [x] 1.6 Add `reevaluateCapabilities` test verifying typed success projection with hidden capabilities read model and invalidation event
- [x] 1.7 Add unsupported capability test verifying `FallbackAdapterRuntimeFailureKind.capabilityUnsupported`
- [x] 1.8 Add `FallbackAdapterRuntime.unavailable(reason)` test verifying all 6 operations return `unavailable` kind
- [x] 1.9 Add disposed runtime test verifying `snapshot` returns `disposed` kind
- [x] 1.10 Add restart projection test verifying replay of stored active configuration and strategy state after runtime recreation
- [x] 1.11 Add domain failure mapping tests: configure strategy to return `noCandidate`, `disabled`, `incompatibleFailure` outcomes and verify runtime maps to corresponding `FallbackAdapterRuntimeFailureKind`

## 2. GREEN: Runtime implementation

- [x] 2.1 Create `lib/src/playback/fallback_adapter_runtime.dart` with `FallbackAdapterBootstrap`, `FallbackAdapterRuntimeFailureKind` (11 values), `FallbackAdapterRuntimeFailure`, `FallbackAdapterRuntimeActionResultKind`, generic `FallbackAdapterRuntimeActionResult<T>`, `FallbackAdapterRuntimeRestartProjection`, `FallbackAdapterRuntimeProjection`, and `FallbackAdapterRuntime` with 7 methods (`snapshot`, `registerCandidate`, `deregisterCandidate`, `selectFallback`, `disable`, `reevaluateCapabilities`, `dispose`)
- [x] 2.2 Add barrel export `export 'src/playback/fallback_adapter_runtime.dart';` in `lib/elaina.dart`
- [x] 2.3 Run focused runtime tests and confirm all pass

## 3. Contract validation

- [x] 3.1 Run `test/playback/fallback_adapter_contract_test.dart` and verify no regression
- [x] 3.2 Run `test/playback/fallback_adapter_runtime_test.dart` and verify all test cases pass
- [x] 3.3 Verify that `FallbackAdapterRuntime.unavailable(reason)` rejects all 6 operations
- [x] 3.4 Verify that disposed runtime rejects all operations

## 4. Checker coverage

- [x] 4.1 Create `tools/fallback_adapter_runtime_check.dart` Dart smoke checker covering: initial snapshot with stored state, registerCandidate success, deregisterCandidate success, selectFallback success, disable success, reevaluateCapabilities success, unsupported capability failure, unavailable rejects all 6 ops, disposed rejects snapshot, restart projection replays stored config
- [x] 4.2 Create `tools/check_fallback_adapter_runtime.ps1` PowerShell boundary checker with: required file presence, Dart smoke run, required runtime terms, barrel export checks, checker terms, forbidden boundary terms, import guards
- [x] 4.3 Run `dart run tools/fallback_adapter_runtime_check.dart` and verify exit 0
- [x] 4.4 Run PowerShell checker and verify "Fallback adapter runtime checks passed."

## 5. Validation gates

- [x] 5.1 Run focused Flutter tests: `test/playback/fallback_adapter_contract_test.dart test/playback/fallback_adapter_runtime_test.dart`
- [x] 5.2 Run `dart analyze` and verify no issues
- [x] 5.3 Run `openspec validate "bootstrap-phase5-vlc-fallback-adapter-runtime" --strict` and verify valid
- [x] 5.4 Run `openspec validate --all` and verify all pass

## 6. Scope guard and completion

- [x] 6.1 Run `findstr /s /n /i` on runtime/test/checker files scanning for forbidden boundary terms (Mpv, Vlc, media-kit, MethodChannel, dart:ffi, DynamicLibrary, ShaderBundle, NativeRenderer, DiagnosticsCenter, RssAutoDownload, OnlineRule, WebView, CaptionRendering, AdvancedCaption, NetworkPolicy, PlayerAdapter import in runtime, FallbackOrchestrator)
- [x] 6.2 Run LSP diagnostics on `lib/src/playback/fallback_adapter_runtime.dart`, `test/playback/fallback_adapter_runtime_test.dart`, `tools/fallback_adapter_runtime_check.dart`, and `lib/elaina.dart` — verify clean
- [x] 6.3 Mark all tasks complete in `tasks.md` and verify `openspec instructions apply` reports `all_done`
