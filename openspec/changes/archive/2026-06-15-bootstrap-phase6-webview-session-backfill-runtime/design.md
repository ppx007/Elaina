## Context

Step 28 already has manual WebView session backfill contracts, storage records, and cache invalidation events. The missing piece is a runtime acceptance layer matching the Step 22-27 pattern: bootstrap composition, scoped gates, typed results, store-backed projections, and restart replay.

The runtime must stay in the Network slice and must not implement a concrete WebView, browser automation, captcha solving, network policy evaluation, diagnostics, or UI behavior.

## Goals / Non-Goals

**Goals:**
- Provide `WebViewSessionBackfillRuntimeBootstrap` and `WebViewSessionBackfillRuntime` over existing `WebViewSessionBackfillStore` and `WebViewSessionBackfill` contracts.
- Return typed `WebViewSessionBackfillRuntimeActionResult<T>` outcomes for snapshot, manual completion, retry descriptor creation, artifact revocation, and capability recording.
- Build `WebViewSessionBackfillRuntimeProjection` and `WebViewSessionBackfillRuntimeRestartProjection` from stored challenge, artifact, attempt, and capability state.
- Publish existing WebView session invalidation events through the optional `CacheInvalidationBus`.

**Non-Goals:**
- No concrete WebView plugin, Flutter widget, browser profile access, hidden browser interaction, or headless automation.
- No automatic captcha solving, challenge bypass, credential guessing, or bot completion.
- No Step 29 network policy implementation and no Step 30 diagnostics behavior.
- No RSS, BT, online-rule, MPV, VLC, native, FFI, or platform channel dependency.

## Decisions

1. **Bootstrap mirrors Steps 22-27.** `WebViewSessionBackfillRuntimeBootstrap` accepts a store, unmodifiable `backfillByScope`, unmodifiable `capabilitiesByScope`, an optional bus, and optional clock. The clock is used only for deterministic test timestamps and artifact activity checks.

2. **Runtime exposes five operations.** `snapshot()`, `completeManually()`, `prepareRetry()`, `revokeArtifact()`, `recordCapability()`, plus `dispose()`. This is enough to cover challenge lifecycle, artifact capture, same-origin retry replay, revocation, and capability projection without adding register/refresh/browser APIs.

3. **Failure kinds stay runtime-sized.** Runtime failure kinds are `capabilityUnsupported`, `unavailable`, `disposed`, `challengeNotFound`, `unsupportedOperation`, `rejectedOrigin`, `artifactInactive`, `missingArtifact`, and `failed`. Fine-grained contract details remain available through `SessionBackfillOutcome` stored in the projection.

4. **Projection is store-first.** Restart projection reads the latest challenge, artifact count, latest backfill attempt, and capability state from `WebViewSessionBackfillStore`. In-memory latest outcome/descriptor/failure are additive and not required for cold restart replay.

5. **Boundary checker is strict but domain-aware.** It forbids concrete automation and later-phase dependencies while allowing `WebViewSessionBackfill`, `ProviderGateway` value contracts already used by descriptor factory, storage contracts, and cache invalidation events.

## Risks / Trade-offs

- **Risk: runtime accidentally becomes a browser automation layer** → mitigated by method set and boundary checker forbidding WebView plugin, headless, bypass, captcha solving, and Flutter UI terms.
- **Risk: failure enum overfits contract internals** → mitigated by collapsed `artifactInactive` and preserving detailed `SessionBackfillOutcome` in projection.
- **Risk: retry preparation crosses into Step 29 network policy** → mitigated by using existing `WebViewSessionBackfillDescriptorFactory.retryDescriptor()` only; no network policy imports or enforcement.
