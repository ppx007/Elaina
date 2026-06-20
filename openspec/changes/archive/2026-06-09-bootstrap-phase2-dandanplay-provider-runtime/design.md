## Context

The architecture plan places DandanplayProvider immediately after BangumiProvider in Phase 2 / Step 11. Current code already contains Dandanplay value types, match/search provider contracts, comment retrieval/posting contracts, provider registration, and an `AcgDataController` with Dandanplay methods. The recently archived Bangumi runtime also introduced an ACG bootstrap that currently uses unavailable Dandanplay placeholders. What is missing is the deterministic runtime slice that proves Dandanplay match/search/comment/post behavior is gateway-governed optional enrichment rather than a playback or danmaku-rendering prerequisite.

This change deliberately stops before Phase 2 / Step 12 basic danmaku rendering. Dandanplay provides comment source data; the Playback-layer renderer runtime, player-clock overlay behavior, density runtime, and filter runtime are separate concerns and should remain isolated from provider transport governance.

## Goals / Non-Goals

**Goals:**

- Provide a deterministic Dandanplay provider runtime/bootstrap that registers Dandanplay with `ProviderGateway` and exposes local media match, subject search, comment retrieval, and comment posting through existing contracts.
- Add Dandanplay request-key helpers and gateway execution helpers that preserve provider id, cache policy, deduplication, and normalized failure semantics.
- Compose Dandanplay runtime into Domain ACG access so `AcgDataController` can call real Dandanplay runtime providers while Bangumi remains independently injectable.
- Preserve optional enrichment: Dandanplay unavailable, unmatched, throttled, unauthenticated-like, retryable, or disposed states must not block playback, subtitle runtime, Bangumi, RSS, BT, online-rule, UI, native player, or local media flows.
- Add focused tests and validation scripts following the Bangumi runtime pattern.

**Non-Goals:**

- No concrete Dandanplay HTTP client, endpoint table, API credentials, account login, token/session storage, WebView flow, or real network dispatch.
- No Step 12 basic danmaku renderer runtime, player-clock overlay service, density runtime, filter runtime, Matrix4 effects, or native player overlay integration.
- No Flutter UI, video detail page binding, playback page binding, RSS, BT, online-rule, streaming, diagnostics behavior, or network-policy implementation changes.
- No migration of persisted provider cache, comment cache, or danmaku storage.

## Decisions

1. **Mirror the Bangumi deterministic runtime pattern.**
   - Rationale: `BangumiProviderRuntime` already proves the gateway-bound provider runtime shape for Phase 2 optional metadata enrichment.
   - Alternative considered: implement Dandanplay REST transport immediately. Rejected because concrete endpoints, auth/session, and network policy belong behind a later adapter.

2. **Keep Dandanplay provider runtime in `lib/src/provider/dandanplay/`.**
   - Rationale: Dandanplay match/search/comments are external provider semantics and should own request keys, fixture data, and gateway execution details.
   - Alternative considered: put runtime in Domain. Rejected because Domain should compose provider abstractions, not own provider request governance.

3. **Treat comments/posting as provider-governed traffic even though `DandanplayCommentProvider` is not currently `GatewayBoundProvider`.**
   - Rationale: the boundary spec says Dandanplay traffic must use ProviderGateway, and comment retrieval/posting are Dandanplay provider traffic.
   - Alternative considered: leave comment provider as an in-memory direct provider. Rejected because it would make the highest-value danmaku source path bypass gateway governance.

4. **Add Domain ACG composition without pulling in Playback danmaku runtime.**
   - Rationale: `AcgDataController` already consumes Dandanplay provider contracts; a Dandanplay ACG runtime can provide real runtime providers without coupling to `BasicDanmakuRenderer`.
   - Alternative considered: bridge Dandanplay comments directly into playback renderer frames. Rejected because Step 12 basic danmaku rendering is the next separate slice.

5. **Use deterministic fixture data and post ledgers.**
   - Rationale: tests can validate match/search/comments/post semantics without API credentials, HTTP transport, or persisted storage.
   - Alternative considered: use mocked HTTP responses. Rejected because HTTP transport is out of scope for this runtime slice.

## Risks / Trade-offs

- **[Risk] Step 11 scope expands into Step 12 renderer work.** → Mitigation: keep this proposal provider/domain-only and explicitly forbid Playback danmaku runtime integration.
- **[Risk] Comment posting gets treated as required for playback or rendering.** → Mitigation: normalize posting failures as provider results and validate other runtime slices still pass.
- **[Risk] Request keys accidentally encode URL paths.** → Mitigation: use semantic keys such as `match:<filename>`, `search:<query>`, `comments:<episode>`, and `post-comment:<episode>:<timestamp>:<text-hash>`.
- **[Risk] `DandanplayCommentProvider` lacks `GatewayBoundProvider`.** → Mitigation: route the deterministic comment provider through the same registered Dandanplay provider id and helper methods without changing the public interface unless implementation requires it.
- **[Risk] Domain ACG runtime naming becomes confusing with `BangumiAcgRuntime`.** → Mitigation: either add a separate `DandanplayAcgRuntime` or evolve the existing ACG runtime composition while keeping public exports explicit and contract-safe.

## Migration Plan

1. Add deterministic gateway-bound Dandanplay provider/comment runtime and bootstrap composition under `lib/src/provider/dandanplay/`.
2. Add or update Domain ACG runtime composition so `AcgDataController` can be backed by real Dandanplay runtime providers.
3. Export only contract-safe runtime/bootstrap surfaces through `lib/elaina.dart`.
4. Add focused tests, smoke validation, and boundary checker scripts.
5. Run `openspec validate "bootstrap-phase2-dandanplay-provider-runtime" --strict`, `openspec validate --all`, `dart analyze`, focused Dandanplay tests, Dandanplay checker scripts, and existing Bangumi/subtitle/player smoke checks.

Rollback before archive is file deletion plus removing the change directory. No persisted schema, token, or cache migration is required.

## Open Questions

- Real Dandanplay endpoint mapping, credentials, request signing, and network policy handoff should be designed in a later concrete adapter change.
- Whether comment posting should publish `DanmakuPosted` on `CacheInvalidationBus` should be deferred unless a deterministic bus-safe path can be added without pulling in Step 12 renderer behavior.
