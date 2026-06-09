## 1. Bangumi Provider Runtime

- [x] 1.1 Add gateway-bound deterministic Bangumi metadata provider implementation in the Provider Bangumi layer for subject lookup, subject search, and episode lookup.
- [x] 1.2 Add deterministic Bangumi auth/progress provider implementation for current session and progress-sync outcomes, including unauthenticated behavior.
- [x] 1.3 Add Bangumi request-key helpers and gateway execution helpers that preserve provider id, cache policy, and normalized ProviderGateway failure mapping.
- [x] 1.4 Add lifecycle-safe Bangumi runtime/bootstrap composition that registers Bangumi provider policy before executing runtime operations.

## 2. Domain ACG Integration

- [x] 2.1 Add Domain-facing ACG/Bangumi bootstrap or runtime helper that exposes an `AcgDataController` backed by deterministic Bangumi runtime providers.
- [x] 2.2 Ensure Bangumi unavailable or unauthenticated results remain optional enrichment and do not require playback, subtitle runtime, Dandanplay, RSS, BT, online-rule, native player, or UI dependencies.
- [x] 2.3 Export only contract-safe Bangumi runtime/bootstrap surfaces through `lib/celesteria.dart` without exposing concrete HTTP, OAuth UI, token storage, or network implementation details.

## 3. Tests and Validation

- [x] 3.1 Add focused Bangumi runtime tests for provider registration, subject lookup, subject search, episode lookup, gateway request keys, cache policy selection, and normalized failures.
- [x] 3.2 Add focused auth/progress tests for active session, missing session, progress-sync success, unauthenticated sync, and disposed runtime behavior.
- [x] 3.3 Add Domain controller integration tests proving Bangumi metadata/progress calls route through the deterministic runtime while non-Bangumi flows remain outside the failure path.
- [x] 3.4 Add or extend provider checker scripts to reject UI, Playback, Subtitle runtime, Dandanplay runtime, RSS runtime, Streaming, Network transport, token storage, WebView OAuth UI, and native player dependencies in the Step 10 runtime slice.
- [x] 3.5 Extend runtime smoke validation to cover the Phase 2 Bangumi provider runtime without reducing Phase 0, Phase 1, or Step 9 checks.
- [x] 3.6 Run `openspec validate "bootstrap-phase2-bangumi-provider-runtime" --strict`, `openspec validate --all`, `dart analyze`, focused Bangumi tests, provider checker scripts, and existing runtime smoke checks.
