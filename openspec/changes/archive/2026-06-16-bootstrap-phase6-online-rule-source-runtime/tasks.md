## 1. RED Test

- [x] 1.1 Create test/provider/online/online_rule_source_runtime_test.dart with 20 test scenarios (initial snapshot, validate success/invalid, evaluate success/failure/disabled/missing-target, disable, reenable disabled→valid, reenable invalid rejection, reenable idempotent, disable missing manifest, unsupported capability, evaluate capability gate, unavailable rejects all 5 ops, disposed, invalidation events evaluate, invalidation events validate, restart projection, normalize output, disable event)
- [x] 1.2 Verify RED tests fail on missing runtime symbols

## 2. GREEN Implementation

- [x] 2.1 Create lib/src/provider/online/online_rule_source_runtime.dart with OnlineRuleSourceRuntimeBootstrap, OnlineRuleSourceRuntimeFailureKind (8 values), OnlineRuleSourceRuntimeFailure, OnlineRuleSourceRuntimeActionResultKind, generic OnlineRuleSourceRuntimeActionResult<T>, OnlineRuleSourceRuntimeRestartProjection, OnlineRuleSourceRuntimeProjection, OnlineRuleSourceRuntime (5 methods + dispose, _gate, _projection, _mapFailureKind, _mapStoredTarget, _mapStoredExtractionKind, _mapStoredUnsupportedKind, _publishEvent)
- [x] 2.2 Add barrel export in lib/celesteria.dart
- [x] 2.3 Verify focused Flutter tests pass

## 3. Contract Coverage

- [x] 3.1 Verify runtime FailureKind mapping covers all OnlineRuleFailureKind values
- [x] 3.2 Verify disable/reenable semantics match spec (disabled→valid only, reject invalid, idempotent)
- [x] 3.3 Verify evaluate persists evaluation snapshot to store
- [x] 3.4 Verify validate persists manifest and validation issues to store

## 4. Validation Checkers

- [x] 4.1 Add tools/online_rule_source_runtime_check.dart Dart smoke checker (no flutter_test)
- [x] 4.2 Add tools/check_online_rule_source_runtime.ps1 PowerShell boundary checker
- [x] 4.3 Run Dart smoke checker — expect exit 0
- [x] 4.4 Run PowerShell boundary checker — expect passed

## 5. Quality Gates

- [x] 5.1 Run focused Flutter tests — expect all pass
- [x] 5.2 Run dart analyze — expect no issues
- [x] 5.3 Run openspec validate --strict — expect valid
- [x] 5.4 Run openspec validate --all — expect 0 failures

## 6. Scope and Completion

- [x] 6.1 Scope guard: scan runtime/test/checker for forbidden boundary terms (gateway/network/crawler/WebView/captcha/DNS/proxy/diagnostics/Flutter/yuc.wiki/libtorrent/registerSource/refreshManifest) — expect no hits
- [x] 6.2 Verify no clock parameter in bootstrap
- [x] 6.3 Mark all tasks complete
