## Why

Phase 6 Step 29 needs the DNS/network policy contract slice after WebView session backfill because provider, RSS, online-rule, and challenge traffic now have enough entry points to require consistent provider-scoped routing and SSRF governance. The existing `network-policy-boundary` spec defines high-level intent, but it does not yet define the typed policy records, deterministic evaluation contracts, storage state, invalidation events, or ProviderGateway handoff needed for implementation.

## What Changes

- Define network policy as provider-scoped contract scaffolding for per-domain rules, DNS resolver intent, DoH/DoT intent, proxy tags, direct/block actions, fallback behavior, and audit metadata.
- Add deterministic network policy evaluation contracts for host/domain/wildcard/CIDR-style matcher intent and normalized SSRF/security failures.
- Persist network policy profiles, ordered rules, provider assignments, evaluation snapshots, and capability state through Storage contracts.
- Route ProviderGateway traffic through policy evaluation descriptors before dispatch, while preserving normalized provider failure semantics.
- Publish explicit invalidation events for policy changes, provider assignment changes, evaluation outcomes, and capability changes.
- Keep this contract-only: no concrete DNS resolver, DoH/DoT client, proxy server, VPN/TUN, kernel filtering, DPI, packet capture, or system-wide routing promise.

## Capabilities

### New Capabilities

- `network-policy-contract`: Typed contracts for provider-scoped DNS/proxy/direct/block routing intent, SSRF evaluation, policy persistence, and deterministic policy decisions.

### Modified Capabilities

- `network-policy-boundary`: Deepen boundary requirements for provider-scoped per-domain policy evaluation, normalized SSRF failures, fallback behavior, and platform capability limits.
- `provider-gateway`: Require ProviderGateway request descriptors to include network policy evaluation before provider dispatch.
- `local-storage-foundation`: Add Storage-layer responsibilities for network policy profiles, rules, provider assignments, evaluation snapshots, and capability state.
- `cache-invalidation-bus`: Add explicit invalidation events for network policy mutation and evaluation state.

## Impact

- Affected layers: Network, Gateway, Storage, Provider, and cache invalidation contracts.
- Expected code impact: Dart contract types in `lib/src/network/network_policy.dart`, storage contracts, ProviderGateway-facing descriptors, invalidation event types, focused tests, runtime checker coverage, automation checker updates, and Phase 6 documentation updates.
- No new runtime dependency is required; concrete resolver/proxy/platform networking adapters remain future work.
