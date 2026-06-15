## Context

Steps 22-26 established a consistent runtime/bootstrap pattern for playback and provider layers: a Bootstrap class accepts unmodifiable maps + store + optional bus, a Runtime class gates operations through disposed/unavailable/unsupported checks, typed ActionResult projections combine in-memory and stored state, and RestartProjection reads from store for cold restart replay.

The online rule source domain (Step 27) already has a complete contract layer (`DeterministicOnlineRuleRuntime` with `validateManifest` + `evaluateTyped` + `normalize`) and storage layer (`OnlineRuleRuntimeStore` with 14 methods, `DeterministicOnlineRuleRuntimeStore`). It needs the same runtime acceptance layer that Steps 22-26 provided.

## Goals / Non-Goals

**Goals:**
- Wrap `DeterministicOnlineRuleRuntime` with bootstrap/runtime acceptance layer
- Gate all operations against disposed/unavailable/unsupported-capability states
- Persist validation results, evaluation snapshots, and manifest state changes through `OnlineRuleRuntimeStore`
- Publish cache invalidation events through `CacheInvalidationBus`
- Support disable/reenable with safe semantics (disabled→valid only, reject invalid)
- Expose typed `ActionResult<Projection>` with 8 FailureKind values

**Non-Goals:**
- No `registerSource` or `refreshManifest` (requires gateway, out of scope)
- No `normalize()` as public runtime method (internal only during evaluate)
- No network fetch, gateway calls, page retrieval
- No clock parameter at bootstrap level (timestamps use `DateTime.now().toUtc()`)
- No magic values — all constants from existing enums/types

## Decisions

**D1: Bootstrap pattern matches Steps 22-26** — `OnlineRuleSourceRuntimeBootstrap` accepts store, unmodifiable `runtimeByScope`, unmodifiable `capabilitiesByScope`, optional bus. No clock. `createRuntime()` produces `OnlineRuleSourceRuntime`.

**D2: Per-method capability gates** — `snapshot()`, `disable()`, `reenable()` gate on `manifestValidation`; `validate()` gates on `manifestValidation`; `evaluate()` gates on `suppliedDocumentEvaluation`. This follows Step 26's per-method gate pattern.

**D3: 8 FailureKind values (collapsed from 10)** — Collapsed `targetMissing`/`requiredOutputMissing`/`unsupportedOperation`/`evaluationFailed` into single `evaluationFailed`. The caller can inspect the detailed `OnlineRuleFailureKind` from the cached `latestEvaluationOutcome` in the projection. `gatewayUnavailable` and `networkPolicyBlocked` map to `sourceUnsupported` since the runtime does not do network operations.

**D4: reenable only restores disabled→valid** — If stored manifest is `invalid`, `reenable()` returns `manifestInvalid` failure. If already `valid`, returns success (idempotent). This is safer than blindly setting to `valid`.

**D5: No normalize() as public method** — `normalize()` is called internally during `evaluate()` and cached in `latestNormalizedOutput`. Callers needing ad-hoc normalization can use `DeterministicOnlineRuleRuntime.normalize()` directly.

**D6: No clock at bootstrap level** — Steps 23-26 showed that clock parameters at the bootstrap level are unused (clock is only needed at the deterministic level). Event timestamps use `DateTime.now().toUtc()`.

## Risks / Trade-offs

- [5 public methods is fewer than Step 26's 6, but more than Steps 22-24's 4-7] → Acceptable; each method has clear scope and no magic values.
- [Collapsed FailureKind means callers must inspect inner outcome for detail] → Acceptable; projection carries `latestEvaluationOutcome` with full `OnlineRuleFailureKind` detail.
- [reenable rejecting invalid manifests means caller must re-validate first] → This is the correct safety semantics — enabling an invalid manifest would be misleading.
