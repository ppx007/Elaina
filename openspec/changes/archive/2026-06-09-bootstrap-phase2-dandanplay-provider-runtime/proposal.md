## Why

Phase 2 / Step 10 Bangumi provider runtime is complete and archived; the architecture plan's next slice is Phase 2 / Step 11, DandanplayProvider. Existing Dandanplay contracts define local media match/search, comment retrieval, comment posting, and provider registration surfaces, but there is no deterministic runtime/bootstrap that routes those Dandanplay operations through `ProviderGateway` while keeping danmaku sourcing optional and independent from playback rendering.

## What Changes

- Add a deterministic Phase 2 Dandanplay provider runtime that composes match, search, comment retrieval, comment posting, provider registration, request keys, gateway execution, normalized failures, and lifecycle-safe access.
- Add gateway-bound Dandanplay provider/comment scaffolding for deterministic offline validation without concrete HTTP transport, API endpoint tables, token/session storage, Flutter UI, native player integration, or real danmaku renderer runtime.
- Add Domain-facing ACG runtime/bootstrap surfaces so `AcgDataController` can consume real Dandanplay runtime providers instead of unavailable placeholders while preserving Bangumi independence.
- Add focused tests and validation proving Dandanplay unavailable or failed enrichment cannot block playback, subtitle runtime, Bangumi metadata/progress, RSS, BT, online-rule, or local media flows.
- No breaking changes.

## Capabilities

### New Capabilities
- `phase2-dandanplay-provider-runtime`: Runtime/bootstrap composition for gateway-governed Dandanplay local-media matching, search, comment retrieval, comment posting, deterministic request keys, optional enrichment behavior, and offline validation.

### Modified Capabilities
- `dandanplay-provider-boundary`: Existing Dandanplay contracts gain runtime-backed requirements for deterministic gateway execution, comment provider governance, optional enrichment, lifecycle behavior, and normalized failure mapping.
- `provider-gateway`: ProviderGateway gains Dandanplay-runtime requirements for typed request keys, registered Dandanplay provider policy, cache policy selection, and normalized failure conversion.
- `repository-baseline`: The repository baseline gains a requirement that Step 11 Dandanplay runtime remains optional enrichment and must not become a playback, subtitle, Bangumi, RSS, BT, online-rule, UI, or native player prerequisite.

## Impact

- Affected code: `lib/src/provider/dandanplay/`, `lib/src/domain/acg/`, public Dart barrel exports, focused Dandanplay runtime tests, and provider validation scripts.
- Affected specs: new `phase2-dandanplay-provider-runtime` plus deltas for `dandanplay-provider-boundary`, `provider-gateway`, and `repository-baseline`.
- Dependencies: no concrete Dandanplay HTTP client, endpoint table, OAuth/session UI, token storage, danmaku renderer runtime, native player, Flutter UI, RSS, BT, online-rule, streaming, or network-policy implementation dependency is introduced in this runtime slice.
