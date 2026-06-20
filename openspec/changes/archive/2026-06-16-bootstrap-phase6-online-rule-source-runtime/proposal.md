## Why

The DeterministicOnlineRuleRuntime already validates manifests and evaluates XPath/CSS/regex extraction against supplied documents. The OnlineRuleRuntimeStore already persists manifests, validation issues, evaluation snapshots, and unsupported operation records. However there is no bootstrap/runtime acceptance layer that provides storage-backed restart replay, typed scoped outcomes, unavailable/disposed gates, or projection snapshots — the same gap that Steps 22-26 filled for their respective runtimes. Without this layer, provider flows cannot restore online rule source state across process restarts or consume scoped rule evaluation decisions through a stable runtime contract.

## What Changes

- Add `OnlineRuleSourceRuntimeBootstrap` to accept rule store, per-scope deterministic runtime instances, per-scope capability matrices, and optional cache invalidation bus, then produce a runtime via `createRuntime()`. No clock parameter.
- Add `OnlineRuleSourceRuntime` with scoped `snapshot()`, `validate()`, `evaluate()`, `disable()`, `reenable()`, and `dispose()` — all returning typed `OnlineRuleSourceRuntimeActionResult<OnlineRuleSourceRuntimeProjection>` outcomes.
- Add `OnlineRuleSourceRuntimeProjection` exposing manifest display name/version/validation state from store, latest evaluation outcome/normalized output from in-memory state, and embedded restart projection.
- Add `OnlineRuleSourceRuntimeRestartProjection` so restart flows can replay manifest validation state, latest evaluation target, and latest evaluation state from store without re-evaluating.
- Add `OnlineRuleSourceRuntimeFailureKind` (8 values: capabilityUnsupported, unavailable, disposed, manifestNotFound, manifestDisabled, manifestInvalid, evaluationFailed, sourceUnsupported) and `OnlineRuleSourceRuntimeFailure` for typed error outcomes.
- Gate all operations against disposed/unavailable/unsupported-capability states. `validate()` requires manifestValidation capability; `evaluate()` requires suppliedDocumentEvaluation capability.
- `reenable()` only restores disabled→valid, rejecting invalid manifests. Idempotent if already valid.
- Persist validation results, evaluation snapshots, and manifest state changes through existing `OnlineRuleRuntimeStore`. Publish existing online rule cache invalidation events through the bus.
- No `registerSource`, no `refreshManifest`, no `normalize()` as public method. No gateway, network, crawler, WebView, captcha, DNS, proxy, diagnostics, Flutter UI, yuc.wiki, or libtorrent dependencies.

## Capabilities

### New Capabilities
- `phase6-online-rule-source-runtime`: Runtime acceptance layer for online rule source — bootstrap, scoped projections, typed outcomes, restart replay, disable/reenable, dispose/unavailable/capability gates.

### Modified Capabilities
- `online-rule-runtime`: Add requirement for runtime acceptance layer that wraps deterministic evaluator with storage-backed projections and typed runtime outcomes.
- `online-rule-runtime-contract`: Add requirement for runtime-level disable/reenable and boundary scope guard against gateway, network, WebView, captcha, DNS, proxy, diagnostics, and Flutter UI.
- `cache-invalidation-bus`: Add requirement that online rule source runtime publishes manifest changed, validation state changed, target evaluated, and unsupported operation recorded events through the bus.
- `local-storage-foundation`: Add requirement for runtime to persist and replay manifest validation, evaluation snapshots, and unsupported operations via existing rule store contracts.
- `repository-baseline`: Add Step 27 runtime acceptance boundary and scope constraint.

## Impact

- New file: `lib/src/provider/online/online_rule_source_runtime.dart`
- Modified barrel: `lib/elaina.dart` (add export)
- New test: `test/provider/online/online_rule_source_runtime_test.dart`
- New tools: `tools/online_rule_source_runtime_check.dart`, `tools/check_online_rule_source_runtime.ps1`
- No changes to existing `online_rule_runtime.dart`, gateway types, or storage contracts
- No gateway, network, WebView, captcha, DNS, proxy, diagnostics, or Flutter UI dependencies
