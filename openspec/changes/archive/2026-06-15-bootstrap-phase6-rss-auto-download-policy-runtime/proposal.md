## Why

The DeterministicRssAutoDownloadPolicyEvaluator already evaluates feed items against declarative policy rules, records decisions, and resolves download sources. The RssAutoDownloadPolicyStore already persists policies, rules, evaluations, candidates, deduplication keys, and enqueue outcomes. However there is no bootstrap/runtime acceptance layer that provides storage-backed restart replay, typed scoped outcomes, unavailable/disposed gates, or projection snapshots — the same gap that Steps 22-25 filled for their respective Playback/Streaming/Domain runtimes. Without this layer, provider flows cannot restore automation state across process restarts or consume scoped RSS auto-download decisions through a stable runtime contract.

## What Changes

- Add `RssAutoDownloadPolicyRuntimeBootstrap` to accept policy store, per-scope deterministic evaluator instances, per-scope RSS automation capability matrices, optional history store, optional cache invalidation bus, and optional clock, then produce a runtime via `createRuntime()`.
- Add `RssAutoDownloadPolicyRuntime` with scoped `snapshot()`, `evaluate()`, `handoff()`, `disable()`, `reenable()`, and `dispose()` — all returning typed `RssAutoDownloadPolicyRuntimeActionResult<RssAutoDownloadPolicyRuntimeProjection>` outcomes.
- Add `RssAutoDownloadPolicyRuntimeProjection` exposing active policy, latest evaluation outcome, latest handoff outcome, latest failure, and restart-replay fields from both in-memory and stored automation state.
- Add `RssAutoDownloadPolicyRuntimeRestartProjection` so restart flows can replay active policy, latest evaluation kind, latest candidate dedupe key, and latest enqueue state without re-evaluating items.
- Add `RssAutoDownloadPolicyRuntimeFailureKind` (capabilityUnsupported, unavailable, disposed, policyNotFound, policyDisabled, automationDisabled, invalidMatcher, unsupportedSource, historyUnavailable, enqueueUnavailable, deduplicated) and `RssAutoDownloadPolicyRuntimeFailure` for typed error outcomes.
- Add `DeterministicRssAutomationHistoryStore` to the storage contracts file for test determinism.
- Gate all operations against disposed/unavailable/unsupported-capability states. For `evaluate()`, additionally check `policyEvaluation` capability. For `handoff()`, additionally check `btTaskHandoff` capability.
- Persist evaluation records, accepted candidates, rejected candidates, deduplication keys, and enqueue outcomes via existing `RssAutoDownloadPolicyStore` on each applicable operation so projections survive restart.
- Publish existing RSS automation cache invalidation events through the bus accepted at bootstrap.
- Export the new runtime from the barrel file.
- Add focused runtime tests, Dart smoke checker, and PowerShell boundary checker.

## Capabilities

### New Capabilities
- `phase6-rss-auto-download-policy-runtime`: Runtime acceptance layer for RSS auto-download policy — bootstrap, scoped projections, typed outcomes, restart replay, dispose/unavailable/capability gates.

### Modified Capabilities
- `rss-auto-download-policy`: Add requirement for runtime acceptance layer that wraps deterministic evaluator with storage-backed projections and typed runtime outcomes; add requirement that evaluation decisions propagate through invalidation bus.
- `rss-auto-download-policy-contract`: Add requirement for runtime-level action results, restart projection contracts, and boundary scope guard against concrete torrent engines, duplicate RSS engines, online source rules, WebView captcha, network policy, diagnostics, mandatory automation, and Flutter UI.
- `cache-invalidation-bus`: Add requirement that RSS auto-download policy runtime publishes feed-item-evaluated, candidate-accepted, candidate-rejected, dedupe-state-changed, and enqueue-outcome-recorded events through the bus.
- `local-storage-foundation`: Add requirement for runtime to persist and replay policy evaluation, candidate, deduplication, and enqueue state via existing policy store contracts.
- `repository-baseline`: Add Step 26 runtime acceptance boundary and scope constraint.

## Impact

- New file: `lib/src/provider/rss/rss_auto_download_runtime.dart`
- Modified file: `lib/src/foundation/storage/rss_auto_download_policy_storage_contracts.dart` (add DeterministicRssAutomationHistoryStore)
- Modified barrel: `lib/celesteria.dart` (add export)
- New test: `test/provider/rss/rss_auto_download_runtime_test.dart`
- New tools: `tools/rss_auto_download_runtime_check.dart`, `tools/check_rss_auto_download_runtime.ps1`
- No changes to existing `rss_auto_download_policy.dart`, `feed_contracts.dart`, or `rss_download_handoff.dart`
- No concrete torrent engine, FeedFetcher/FeedParser, libtorrent, yuc.wiki-specific, WebView/captcha, DNS/network policy, diagnostics, or Flutter UI dependencies
