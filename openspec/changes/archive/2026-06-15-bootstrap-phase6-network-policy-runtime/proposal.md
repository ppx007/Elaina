## Why

Network policy contracts, storage records, evaluator scaffolding, and invalidation events already exist, but there is no runtime acceptance layer that ties provider-scoped policy evaluation to store-backed projections, restart replay, typed outcomes, and runtime gates. Step 29 adds that boundary so Gateway and Network flows can evaluate declarative policy intent without introducing concrete DNS, proxy, VPN, or transport implementations.

## What Changes

- Add a Network Policy runtime acceptance layer that wraps existing evaluator, storage, capability, and invalidation contracts.
- Add scoped runtime projections and restart projections for provider assignments, latest evaluations, block outcomes, and capability state.
- Add typed runtime outcomes for disposed, unavailable, unsupported-capability, missing-policy, disabled-policy, invalid-assignment, and evaluation failures.
- Add a runtime bootstrap that accepts per-scope evaluators, per-scope capability matrices, storage, and an optional cache invalidation bus.
- Add runtime tests and boundary checkers for provider-scoped policy evaluation, SSRF/block replay, assignment state, and no concrete networking leakage.
- Keep Step 29 declarative only; do not add DNS clients, proxy clients, VPN/TUN, packet inspection, provider dispatch, diagnostics behavior, or UI/native/platform dependencies.

## Capabilities

### New Capabilities
- `phase6-network-policy-runtime`: Runtime acceptance layer for provider-scoped network policy evaluation, assignment replay, typed outcomes, restart projections, and boundary validation.

### Modified Capabilities
- `network-policy-contract`: Add runtime acceptance requirements for typed evaluation outcomes, provider assignment projection, and runtime gates over the existing deterministic evaluator.
- `network-policy-boundary`: Add Step 29 runtime boundary requirements that keep DNS/proxy policy declarative and provider-scoped.
- `cache-invalidation-bus`: Add runtime publication requirements for network policy evaluation, block, assignment, and capability events.
- `local-storage-foundation`: Add runtime replay requirements for network policy store state.
- `repository-baseline`: Record the Step 29 runtime boundary and concrete-networking exclusion.

## Impact

Affected code will include a new `lib/src/network/network_policy_runtime.dart` runtime, its barrel export in `lib/elaina.dart`, a focused runtime test, a Dart smoke checker, a PowerShell boundary checker, and archived OpenSpec change artifacts after completion.
