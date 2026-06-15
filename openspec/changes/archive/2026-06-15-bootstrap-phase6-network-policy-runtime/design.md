## Context

Step 29 already has declarative network policy contracts, deterministic evaluator scaffolding, storage records, Gateway handoff descriptors, and cache invalidation events. The missing piece is the same runtime acceptance layer introduced for Steps 22-28: bootstrap composition, scoped gates, typed results, store-backed projections, and restart replay.

The runtime must stay in the Network slice and must not implement concrete DNS resolution, proxy transport, VPN/TUN routing, packet inspection, provider dispatch, diagnostics, UI behavior, native bindings, or platform channels.

## Goals / Non-Goals

**Goals:**
- Provide `NetworkPolicyRuntimeBootstrap` and `NetworkPolicyRuntime` over existing `NetworkPolicyStore`, `NetworkPolicyEvaluator`, and `NetworkPolicyCapabilityMatrix` contracts.
- Return typed `NetworkPolicyRuntimeActionResult<T>` outcomes for snapshot, evaluation, provider assignment, disable, reenable, capability recording, and disposal gates.
- Build `NetworkPolicyRuntimeProjection` and `NetworkPolicyRuntimeRestartProjection` from stored profiles, rules, assignments, evaluations, block outcomes, and capability state.
- Publish existing network policy invalidation events through the optional `CacheInvalidationBus` after store-visible changes.

**Non-Goals:**
- No concrete DNS resolver/client, DoH client, DoT client, proxy client, proxy server, PAC parser, VPN, TUN, kernel filtering, DPI, packet capture, or zero-leak routing control.
- No provider dispatch, HTTP client, Gateway request execution, transport retry, or network socket behavior.
- No Step 30 diagnostics implementation or diagnostics-controlled network policy mutation.
- No Flutter UI, native plugin, FFI, platform channel, RSS, BT, online-rule, WebView, captcha, MPV, VLC, media-kit, yuc.wiki, or libtorrent dependency.

## Decisions

1. **Bootstrap mirrors adjacent runtimes.** `NetworkPolicyRuntimeBootstrap` accepts a `NetworkPolicyStore`, unmodifiable `evaluatorByScope`, unmodifiable `capabilitiesByScope`, and an optional bus. It does not accept a clock because existing network policy storage records already carry timestamps supplied by callers and deterministic tests can seed records explicitly.

2. **Runtime exposes focused operations.** `snapshot()`, `evaluate()`, `assignProvider()`, `disable()`, `reenable()`, `recordCapability()`, and `dispose()` cover provider policy replay, evaluation, assignment state, capability projection, and lifecycle gates without adding resolver/proxy APIs.

3. **Failure kinds stay runtime-sized.** Runtime failures are `capabilityUnsupported`, `unavailable`, `disposed`, `policyNotFound`, `policyDisabled`, `evaluationFailed`, and `invalidAssignment`. Fine-grained SSRF or policy block reasons remain on `NetworkPolicyBlocked` and stored block outcomes.

4. **Projection is store-first.** Restart projection reads assignment, latest evaluation, latest block outcome, and capability state from `NetworkPolicyStore`. In-memory decisions are not required for cold restart replay.

5. **Evaluation persists before publishing.** `evaluate()` delegates to the scoped evaluator, records a snapshot through storage, records/publishes a block outcome when blocked, then publishes invalidation events. Consumers observe events only after the corresponding store state is available.

6. **Disable/reenable remain assignment scoped.** The runtime disables a provider scope by recording disabled assignment intent through existing storage semantics and reenables only that target scope. It never mutates global routing state or unrelated provider assignments.

7. **Boundary checker is strict but contract-aware.** It forbids concrete networking and later-phase implementation terms while allowing declarative `NetworkPolicy`, storage contracts, Gateway handoff value types, and cache invalidation payloads.

## Risks / Trade-offs

- **Risk: runtime grows into a concrete networking layer** -> mitigated by the method set, import guard, and boundary checker forbidding DNS/proxy clients, VPN/TUN, sockets, DPI, packet capture, native bindings, and platform channels.
- **Risk: runtime failure enum duplicates policy block details** -> mitigated by collapsing evaluation failures at runtime level and preserving normalized policy details on `NetworkPolicyDecision`/stored block records.
- **Risk: disable/reenable semantics overreach storage contracts** -> mitigated by modeling only provider-scoped assignment state and adjusting tests to existing store capabilities instead of inventing global policy toggles.
- **Risk: diagnostics leakage arrives one step early** -> mitigated by allowing persisted evaluation snapshots and invalidation payloads only, with no diagnostics action or diagnostics-owned mutation behavior.
