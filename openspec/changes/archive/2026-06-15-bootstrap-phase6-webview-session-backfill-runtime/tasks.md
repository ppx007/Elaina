## 1. RED Test

- [x] 1.1 Create `test/network/webview_session_backfill_runtime_test.dart` with runtime scenarios for initial snapshot, manual completion, same-origin retry preparation, cross-origin rejection, artifact revocation, capability recording, unsupported capability, unavailable runtime, disposed runtime, invalidation events, and restart projection replay
- [x] 1.2 Verify RED tests fail on missing runtime symbols before implementation

## 2. GREEN Implementation

- [x] 2.1 Create `lib/src/network/webview_session_backfill_runtime.dart` with `WebViewSessionBackfillRuntimeBootstrap`, typed runtime failure/action result types, restart/projection models, scoped gates, and runtime operations (`snapshot`, `completeManually`, `prepareRetry`, `revokeArtifact`, `recordCapability`, `dispose`)
- [x] 2.2 Add barrel export `export 'src/network/webview_session_backfill_runtime.dart';` in `lib/elaina.dart`
- [x] 2.3 Run focused runtime tests and confirm all pass

## 3. Contract Coverage

- [x] 3.1 Verify runtime failure mapping covers unsupported capability, unavailable, disposed, missing challenge, unsupported operation, rejected origin, inactive artifact, missing artifact, and failed backfill cases
- [x] 3.2 Verify manual completion delegates to `WebViewSessionBackfill.completeManually`, stores challenge/artifact state, and publishes challenge/artifact invalidation events
- [x] 3.3 Verify retry preparation persists success/failure attempts and rejects cross-origin or inactive artifact reuse
- [x] 3.4 Verify restart projection reads stored challenge, artifact, attempt, and capability state without invoking a concrete WebView

## 4. Validation Checkers

- [x] 4.1 Add `tools/webview_session_backfill_runtime_check.dart` Dart smoke checker covering the runtime happy path, failure gates, and restart replay
- [x] 4.2 Add `tools/check_webview_session_backfill_runtime.ps1` PowerShell boundary checker for required files, barrel export, smoke run, and forbidden Step 28 boundary terms
- [x] 4.3 Run Dart smoke checker and verify exit 0
- [x] 4.4 Run PowerShell boundary checker and verify passed output

## 5. Quality Gates

- [x] 5.1 Run focused Flutter tests for WebView session backfill contract and runtime tests
- [x] 5.2 Run `dart analyze` and verify no issues
- [x] 5.3 Run `openspec validate "bootstrap-phase6-webview-session-backfill-runtime" --strict` and verify valid
- [x] 5.4 Run `openspec validate --all` and verify all pass

## 6. Scope and Completion

- [x] 6.1 Scope guard: scan runtime, test, and checker files for forbidden boundary terms (concrete WebView plugin, captcha solving, challenge bypass, credential guessing, bot completion, headless automation, hidden browser interaction, shared profile cookie access, NetworkPolicy, diagnostics, RSS, BT, online-rule, native, FFI, platform channel, Flutter UI) and verify no leakage
- [x] 6.2 Mark all tasks complete in this file after implementation and validation
- [x] 6.3 Archive `bootstrap-phase6-webview-session-backfill-runtime` and verify `openspec validate --all` passes after sync
