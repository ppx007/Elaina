## 1. RED Test

- [x] 1.1 Create `test/network/network_policy_runtime_test.dart` with runtime scenarios for initial snapshot, provider assignment, allowed evaluation, SSRF/block evaluation, block outcome replay, capability recording, unsupported capability, disabled policy, unavailable runtime, disposed runtime, invalidation events, and restart projection replay
- [x] 1.2 Verify RED tests fail on missing runtime symbols before implementation

## 2. GREEN Implementation

- [x] 2.1 Create `lib/src/network/network_policy_runtime.dart` with `NetworkPolicyRuntimeBootstrap`, typed runtime failure/action result types, restart/projection models, scoped gates, and runtime operations (`snapshot`, `evaluate`, `assignProvider`, `disable`, `reenable`, `recordCapability`, `dispose`)
- [x] 2.2 Add barrel export `export 'src/network/network_policy_runtime.dart';` in `lib/elaina.dart`
- [x] 2.3 Run focused runtime tests and confirm all pass

## 3. Contract Coverage

- [x] 3.1 Verify runtime failure mapping covers unsupported capability, unavailable, disposed, missing policy, disabled policy, invalid assignment, and evaluation failure cases
- [x] 3.2 Verify evaluation delegates to `NetworkPolicyEvaluator`, stores evaluation snapshots, preserves `NetworkPolicyBlocked` details, and publishes evaluation/block invalidation events
- [x] 3.3 Verify provider assignment, disable, reenable, and capability recording are provider-scoped and do not mutate unrelated provider state
- [x] 3.4 Verify restart projection reads stored assignment, evaluation, block, and capability state without invoking concrete networking behavior

## 4. Validation Checkers

- [x] 4.1 Add `tools/network_policy_runtime_check.dart` Dart smoke checker covering the runtime happy path, failure gates, invalidation events, and restart replay
- [x] 4.2 Add `tools/check_network_policy_runtime.ps1` PowerShell boundary checker for required files, barrel export, smoke run, and forbidden Step 29 boundary terms
- [x] 4.3 Run Dart smoke checker and verify exit 0
- [x] 4.4 Run PowerShell boundary checker and verify passed output

## 5. Quality Gates

- [x] 5.1 Run focused Flutter tests for network policy contract and runtime tests
- [x] 5.2 Run `dart analyze` and verify no new issues
- [x] 5.3 Run `openspec validate "bootstrap-phase6-network-policy-runtime" --strict` and verify valid
- [x] 5.4 Run `openspec validate --all` and verify all pass

## 6. Scope and Completion

- [x] 6.1 Scope guard: scan runtime, test, and checker files for forbidden boundary terms (concrete DNS/proxy client, VPN, TUN, kernel filtering, DPI, packet capture, sockets, platform plugin, diagnostics implementation, provider dispatch, RSS, BT, online-rule, WebView, captcha, native, FFI, platform channel, Flutter UI) and verify no leakage
- [x] 6.2 Mark all tasks complete in this file after implementation and validation
- [x] 6.3 Archive `bootstrap-phase6-network-policy-runtime` and verify `openspec validate --all` passes after sync
