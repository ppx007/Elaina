## Context

The architecture plan places BangumiProvider immediately after basic subtitles in Phase 2 / Step 10. Current code contains contract-level Bangumi value types, provider interfaces, auth/progress interfaces, and provider registration, plus an `AcgDataController` that delegates directly to injected Bangumi providers. What is missing is a deterministic runtime/bootstrap slice that proves Bangumi metadata and optional progress sync are gateway-governed enrichment rather than a playback prerequisite.

External API lookup did not produce reliable endpoint-level documentation through the available tools, so this change deliberately avoids hardcoding HTTP endpoint paths or OAuth transport details. The runtime will model request keys, session/progress outcomes, and normalized gateway failures so a later concrete Bangumi HTTP adapter can plug in without changing Domain or UI contracts.

## Goals / Non-Goals

**Goals:**

- Provide a deterministic Bangumi provider runtime/bootstrap that registers Bangumi with `ProviderGateway` and exposes subject lookup, subject search, episode lookup, optional session state, and progress sync through existing contracts.
- Add gateway-bound Bangumi metadata/auth scaffolding that converts ProviderGateway responses/failures into `AcgProviderResult` outcomes.
- Preserve playback independence: local playback, subtitle runtime, Dandanplay, RSS, BT, and online-rule flows must run when Bangumi is unavailable or unauthenticated.
- Add tests and validation scripts for registration, request key formation, gateway execution, unauthenticated progress behavior, failure normalization, and Domain controller integration.

**Non-Goals:**

- No concrete Bangumi HTTP client, endpoint table, OAuth browser flow, WebView auth screen, token persistence, refresh-token storage, or real network dispatch.
- No UI login page, profile page, collection screen, or video detail page binding.
- No Dandanplay provider runtime, danmaku rendering, RSS seasonal matching queue implementation, or provider cache persistence.
- No changes to playback, subtitle runtime, BT, online-rule runtime, native player adapters, or diagnostics center behavior.

## Decisions

1. **Create a deterministic runtime before concrete HTTP adapters.**
   - Rationale: The project already has ProviderGateway and Bangumi contracts; proving request governance and optional enrichment is the next stable contract layer.
   - Alternative considered: implement real Bangumi REST calls immediately. Rejected because endpoint/OAuth evidence was not reliable in this session and real transport belongs behind a later adapter.

2. **Place gateway-bound Bangumi scaffolding in `lib/src/provider/bangumi/`.**
   - Rationale: Provider implementations own external provider semantics and can depend on ProviderGateway contracts.
   - Alternative considered: put runtime in Domain. Rejected because Domain should orchestrate ACG data flows, not own provider request-key and gateway execution details.

3. **Expose Domain access through an ACG runtime/bootstrap wrapper.**
   - Rationale: `AcgDataController` already consumes provider interfaces; a bootstrap can compose deterministic Bangumi providers while preserving controller-level contracts.
   - Alternative considered: have UI instantiate Bangumi providers. Rejected because UI must not depend directly on Bangumi or provider internals.

4. **Model OAuth/session as optional state, not required transport.**
   - Rationale: The plan explicitly says progress sync is enrichment, and playback must remain available without Bangumi authentication.
   - Alternative considered: fail controller construction when unauthenticated. Rejected because it violates the existing Bangumi boundary spec.

5. **Use deterministic fixture data and loader callbacks.**
   - Rationale: Tests can verify subject/episode/session/progress semantics without real network, token storage, or API credentials.
   - Alternative considered: mock HTTP responses. Rejected because HTTP transport is out of scope for this runtime slice.

## Risks / Trade-offs

- **[Risk] Endpoint assumptions leak into contracts.** → Mitigation: use semantic request keys such as `subject:<id>` and `progress:<subject>:<episode>`, not concrete URL paths.
- **[Risk] Auth state gets treated as a playback dependency.** → Mitigation: unauthenticated session/progress returns normalized enrichment failures and validation proves playback-adjacent checks still pass.
- **[Risk] ProviderGateway behavior is over-specified.** → Mitigation: rely on existing `ProviderGatewayRequest<T>` and `ProviderGatewayResponse<T>` contracts; do not add retry/cache internals.
- **[Risk] Runtime scope expands into Dandanplay or seasonal matching.** → Mitigation: reserve Dandanplay for Step 11 and seasonal match queues for Phase 3 Step 17.

## Migration Plan

1. Add deterministic gateway-bound Bangumi provider/auth implementations and runtime/bootstrap composition under Provider/Domain ACG boundaries.
2. Add ACG controller bootstrap or runtime helper that composes Bangumi providers with existing Dandanplay placeholders without requiring playback or UI dependencies.
3. Extend public exports only for contract-safe runtime/bootstrap surfaces.
4. Add focused tests and checker scripts.
5. Run `openspec validate "bootstrap-phase2-bangumi-provider-runtime" --strict`, `openspec validate --all`, `dart analyze`, focused Bangumi runtime tests, provider checker scripts, and existing runtime smoke checks.

Rollback before archive is file deletion plus removing the change directory. No persisted schema or token migration is required.

## Open Questions

- Concrete Bangumi endpoint mapping and OAuth transport details must be revisited when implementing the real HTTP adapter.
- Token persistence should be designed with Storage and WebView/session policies in a later change, not in this deterministic runtime slice.
