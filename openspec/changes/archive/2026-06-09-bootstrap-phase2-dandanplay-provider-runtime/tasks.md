## 1. Dandanplay Provider Runtime

- [x] 1.1 Add deterministic gateway-bound Dandanplay match/search provider implementation in the Provider Dandanplay layer.
- [x] 1.2 Add deterministic Dandanplay comment provider implementation for comment retrieval and comment posting outcomes.
- [x] 1.3 Add Dandanplay request-key helpers and gateway execution helpers that preserve provider id, cache policy, deduplication, and normalized ProviderGateway failure mapping.
- [x] 1.4 Add lifecycle-safe Dandanplay runtime/bootstrap composition that registers Dandanplay provider policy before executing runtime operations and rejects disposed direct gateway execution.

## 2. Domain ACG Integration

- [x] 2.1 Add or update Domain-facing ACG/Dandanplay runtime helper that exposes an `AcgDataController` backed by deterministic Dandanplay runtime providers.
- [x] 2.2 Ensure Dandanplay unavailable, unmatched, post-failed, throttled, retryable, or disposed results remain optional enrichment and do not require playback, subtitle runtime, Bangumi, RSS, BT, online-rule, native player, or UI dependencies.
- [x] 2.3 Export only contract-safe Dandanplay runtime/bootstrap surfaces through `lib/elaina.dart` without exposing concrete HTTP, account login, token storage, network, Playback danmaku renderer, or UI details.

## 3. Tests and Validation

- [x] 3.1 Add focused Dandanplay runtime tests for provider registration, local media match, subject search, comment retrieval, comment posting, request keys, cache policy selection, and normalized failures.
- [x] 3.2 Add focused lifecycle tests for disposed match/search/comments/post/direct gateway execution and no-dispatch behavior after disposal.
- [x] 3.3 Add Domain controller integration tests proving Dandanplay calls route through deterministic runtime while Bangumi and non-Dandanplay flows remain outside the failure path.
- [x] 3.4 Add or extend provider checker scripts to reject UI, Playback danmaku runtime, Subtitle runtime, Bangumi runtime dependency, RSS runtime, Streaming, Network transport, token storage, WebView/login UI, concrete HTTP, and native player dependencies in the Step 11 runtime slice.
- [x] 3.5 Extend runtime smoke validation to cover the Phase 2 Dandanplay provider runtime without reducing Phase 0, Phase 1, Step 9, or Step 10 checks.
- [x] 3.6 Run `openspec validate "bootstrap-phase2-dandanplay-provider-runtime" --strict`, `openspec validate --all`, `dart analyze`, focused Dandanplay tests, provider checker scripts, and existing Bangumi/subtitle/player runtime smoke checks.
