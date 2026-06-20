## Why

Phase 6 Step 27 is the next architecture-plan slice after RSS auto-download: online rule sources for search, detail, episode, and playable-source parsing. The bootstrap `online-rule-runtime` contract names declarative manifests and safe extraction primitives, but it lacks durable manifest storage, typed validation/evaluation outcomes, normalized read models, gateway/network handoff contracts, invalidation events, runtime checks, and checker coverage comparable to the completed Step 26 contract slice.

## What Changes

- Add durable online rule runtime storage contracts for source manifests, manifest versions, rule sets, validation issues, evaluation snapshots, retrieval outcomes, and source capability state.
- Deepen online rule runtime contracts with typed manifest registration, validation, refresh, page retrieval, extraction evaluation, unsupported-operation, disable, and normalized output outcomes/failures.
- Define deterministic contract scaffolding for CSS selector, XPath 1.0 intent, and regex extraction over supplied documents without adding concrete crawler, scraper, JavaScript, WASM, or WebView behavior.
- Model search, detail, episode, and playable-source outputs as typed Domain-facing read models that remain optional and cannot become a prerequisite for local playback, manual URL playback, BT virtual-stream playback, RSS refresh, or media-library use.
- Add ProviderGateway and network-policy boundary requirements for online rule manifest/page retrieval without direct source-owned transport logic.
- Publish invalidation events when manifests change, validation state changes, evaluations run, unsupported operations are recorded, or rule-source capability state changes.
- Add focused tests, runtime checks, Phase 6 checker rules, and documentation proving Step 27 remains declarative, gateway-routed, extension-neutral, and independent of Step 28 WebView session backfill.

## Capabilities

### New Capabilities
- `online-rule-runtime-contract`: Durable Step 27 contract for online rule manifest storage, typed validation/evaluation, normalized outputs, gateway/network handoff, invalidation, and optional rule-source behavior.

### Modified Capabilities
- `online-rule-runtime`: Refine the bootstrap online rule runtime into typed outcomes, deterministic declarative extraction, normalized search/detail/episode/playable-source read models, unsupported-operation reporting, and optional capability gating semantics.
- `local-storage-foundation`: Add online rule persistence responsibilities for manifests, versions, rule sets, validation issues, evaluation snapshots, retrieval outcomes, and capability state.
- `provider-gateway`: Clarify that online rule manifest updates and page retrieval route through ProviderGateway with registered rate/retry/negative-cache policy and normalized failures.
- `network-policy-boundary`: Clarify that rule-source traffic is provider-scoped network-policy traffic and must inherit SSRF protections and platform capability reporting.
- `cache-invalidation-bus`: Add online rule invalidation events for manifest changes, validation changes, evaluation snapshots, unsupported operations, and source capability changes.

## Impact

- Affected Dart contracts are expected under `lib/src/provider/online/`, `lib/src/foundation/storage/`, `lib/src/foundation/cache_invalidation/`, `lib/src/foundation/gateway/`, `lib/src/network/`, and `lib/elaina.dart`.
- New storage contract file expected under `lib/src/foundation/storage/` for online rule runtime persistence.
- Verification updates expected in `test/provider/online/`, `tools/player_core_runtime_check.dart`, `tools/check_automation_extension_core.ps1`, and `docs/phase6-automation-extension-core.md`.
- No new external dependencies, concrete crawler/scraper implementation, JavaScript/WASM/scriptlet execution, WebView challenge flow, automatic captcha solving, concrete DNS/proxy resolver, diagnostics action, Flutter UI, yuc.wiki special case, or mandatory online-source startup path.
