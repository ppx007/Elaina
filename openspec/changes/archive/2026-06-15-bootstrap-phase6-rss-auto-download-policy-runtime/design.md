## Context

Step 26 adds the RSS auto-download policy runtime acceptance layer. The contract layer (`rss_auto_download_policy.dart`, 725 lines) already provides `DeterministicRssAutoDownloadPolicyEvaluator` with `evaluateTyped()` and `rssAutomationHandoffFromCandidate()`. The storage layer (`rss_auto_download_policy_storage_contracts.dart`, 588 lines) provides `DeterministicRssAutoDownloadPolicyStore` with all persistence methods. The cache invalidation bus already defines 6 RSS-specific events (`RssAutoDownloadFeedItemEvaluated`, `RssAutoDownloadCandidateAccepted`, `RssAutoDownloadCandidateRejected`, `RssAutoDownloadDedupeStateChanged`, `RssAutoDownloadEnqueueOutcomeRecorded`, `RssAutoDownloadPolicyChanged`). This design follows the established runtime/bootstrap pattern from Steps 22-25.

## Goals

- Wrap `DeterministicRssAutoDownloadPolicyEvaluator` with a scoped bootstrap/runtime acceptance layer
- Provide typed `RssAutoDownloadPolicyRuntimeActionResult<T>` outcomes for all operations
- Persist evaluation, candidate, dedupe, and enqueue records via existing `RssAutoDownloadPolicyStore`
- Publish RSS cache invalidation events through the bus
- Enable restart replay via `RssAutoDownloadPolicyRuntimeRestartProjection` reading from store
- Gate operations against disposed/unavailable/unsupported-capability states
- Add `DeterministicRssAutomationHistoryStore` to storage contracts for test determinism

## Non-Goals

- No concrete torrent engine or BT task creation (handoff produces read model only)
- No FeedFetcher/FeedParser integration
- No libtorrent bindings
- No yuc.wiki special-casing
- No WebView/captcha flow
- No DNS/network policy behavior
- No diagnostics center actions
- No Flutter UI dependencies
- No mandatory automation startup
- No `rss_download_handoff.dart` or `bt_task_core` imports

## Decisions

### D1: Bootstrap pattern matches Steps 22-25

`RssAutoDownloadPolicyRuntimeBootstrap` accepts `RssAutoDownloadPolicyStore`, unmodifiable maps for `evaluatorByScope` and `capabilitiesByScope`, optional `RssAutomationHistoryStore`, optional `CacheInvalidationBus`, optional `clock`, and produces `RssAutoDownloadPolicyRuntime` via `createRuntime()`. This follows the identical pattern used in Steps 22-25.

### D2: Gate checks per-method capability requirements

The standard gate cascade (disposed -> unavailable -> missing scope -> unsupported general capability) is extended with per-method capability checks:
- `snapshot()`, `evaluate()`, `disable()`, `reenable()` require `RssAutomationCapability.policyEvaluation`
- `handoff()` requires `RssAutomationCapability.btTaskHandoff`

### D3: Projection combines stored + in-memory state

`RssAutoDownloadPolicyRuntimeProjection` reads active policy from `RssAutoDownloadPolicyStore` (via `policyById`/`listPolicies`) and combines with in-memory latest evaluation/handoff outcomes. `RssAutoDownloadPolicyRuntimeRestartProjection` reads evaluation kind, candidate dedupe key, and enqueue state from store for restart replay.

### D4: Failure kinds map from contract domain failures

11 failure kinds: standard trio (capabilityUnsupported, unavailable, disposed) + domain kinds (policyNotFound, policyDisabled, automationDisabled, invalidMatcher, unsupportedSource, historyUnavailable, enqueueUnavailable, deduplicated). The `_mapFailureKind()` method maps `RssAutomationFailureKind` to runtime failure kinds.

### D5: evaluate() persists results to policy store

`evaluate()` delegates to `DeterministicRssAutoDownloadPolicyEvaluator.evaluateTyped()`, then persists evaluation records, accepted/rejected candidates, and dedupe keys to `RssAutoDownloadPolicyStore`. It also publishes cache invalidation events. This matches how Steps 22-25 runtimes add storage persistence around their deterministic inner components.

### D6: handoff() does not invoke enqueuer

`handoff()` calls `rssAutomationHandoffFromCandidate()` to produce `RssAutomationBtHandoffReadModel`, persists accepted candidate and enqueue outcome records, publishes events, but does NOT call any BT task enqueuer. The caller chains: `runtime.evaluate()` -> `runtime.handoff()` -> `enqueuer.enqueue()`. No `bt_task_core.dart` or `rss_download_handoff.dart` imports.

### D7: DeterministicRssAutomationHistoryStore in storage contracts file

`DeterministicRssAutomationHistoryStore` is added to `rss_auto_download_policy_storage_contracts.dart` (requires importing `rss_auto_download_policy.dart` for `RssAutomationHistoryEntry`, `RssAutomationAccepted`, `FeedDedupeKey` — no circular dependency since policy file does not import storage file).

## Risks

1. **6 methods vs 3-4 in Steps 22-25**: The RSS runtime has more methods (snapshot, evaluate, handoff, disable, reenable, dispose) than prior runtimes, increasing test surface. Mitigated by reusing established test patterns per method.
2. **evaluate() persistence complexity**: evaluate() must iterate decisions and persist different record types per decision kind (accepted -> candidate + dedupe, rejected -> rejection, deduplicated -> dedupe). Mitigated by clear per-decision-type handling in implementation.
3. **historyStore dependency**: evaluate() requires `RssAutomationHistoryStore` for dedup checking. The runtime resolves it from bootstrap's optional `historyStore` or creates an ephemeral `DeterministicRssAutomationHistoryStore`.
