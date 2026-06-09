## Why

Phase 2 / Step 9 basic subtitles is complete; the architecture plan's next slice is Phase 2 / Step 10, BangumiProvider. Existing Bangumi contracts define subject, episode, auth session, progress update, and provider registration surfaces, but there is no deterministic runtime/bootstrap that routes Bangumi metadata and optional progress sync through `ProviderGateway` while preserving playback independence.

## What Changes

- Add a deterministic Phase 2 Bangumi provider runtime that composes Bangumi metadata provider, auth/progress provider, provider registration, gateway request keys, normalized provider failures, and lifecycle-safe runtime access.
- Add gateway-bound Bangumi provider scaffolding for subject lookup, subject search, episode lookup, current OAuth/session state, and progress-sync outcomes without concrete HTTP transport or UI OAuth screens.
- Add Domain-facing runtime/bootstrap surfaces so `AcgDataController` can consume Bangumi subject, episode, session, and progress sync behavior through Provider/Gateway contracts.
- Add validation and focused tests proving unauthenticated Bangumi remains optional enrichment and cannot block playback, subtitle runtime, Dandanplay, RSS, BT, or online-rule flows.
- No breaking changes.

## Capabilities

### New Capabilities
- `phase2-bangumi-provider-runtime`: Runtime/bootstrap composition for gateway-governed Bangumi subject lookup, episode lookup, optional OAuth/session state, progress sync, and deterministic offline validation.

### Modified Capabilities
- `bangumi-provider-boundary`: Existing Bangumi contracts gain runtime-backed requirements for deterministic gateway execution, optional auth/session lifecycle, progress-sync outcomes, and normalized failure mapping.
- `provider-gateway`: ProviderGateway gains Bangumi-runtime requirements for typed provider request keys, registration preservation, deterministic cache policy selection, and normalized gateway failure conversion.
- `repository-baseline`: The project baseline gains a requirement that Step 10 Bangumi runtime must remain optional enrichment and must not become a core playback prerequisite.

## Impact

- Affected code: `lib/src/provider/bangumi/`, `lib/src/domain/acg/`, public Dart barrel exports, focused Bangumi runtime tests, and provider validation scripts.
- Affected specs: new `phase2-bangumi-provider-runtime` plus deltas for `bangumi-provider-boundary`, `provider-gateway`, and `repository-baseline`.
- Dependencies: no concrete Bangumi HTTP client, OAuth WebView UI, token storage, native player, playback UI, Dandanplay, RSS, streaming, or network-policy implementation dependency is introduced in this runtime slice.
