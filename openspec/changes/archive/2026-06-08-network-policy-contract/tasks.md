## 1. Network Policy Contracts

- [x] 1.1 Add Network-layer policy profile, provider assignment, resolver intent, proxy intent, fallback, audit metadata, and evaluation outcome contract types.
- [x] 1.2 Add deterministic policy evaluator scaffolding for exact host, domain suffix, wildcard host, and CIDR-style matcher intent without concrete DNS resolution.
- [x] 1.3 Add normalized SSRF/security failure contracts for disallowed schemes, loopback, link-local, private network, unsafe redirect, blocked host, and unsupported capability cases.

## 2. Storage and Events

- [x] 2.1 Add Storage-layer contracts and deterministic store scaffolding for network policy profiles, ordered rules, provider assignments, evaluation snapshots, block outcomes, and capability state.
- [x] 2.2 Export the new network policy storage domain through storage foundation contracts and the public Dart contract barrel as appropriate.
- [x] 2.3 Add CacheInvalidationBus events for policy profile changes, provider assignment changes, rule changes, evaluation outcomes, block decisions, and capability changes.

## 3. Gateway and Boundary Integration

- [x] 3.1 Add ProviderGateway-facing network policy handoff descriptors that preserve provider identity, cache key, request URI, redirect source, and policy requirement metadata.
- [x] 3.2 Extend automation boundary documentation and checkers so network policy remains provider-scoped declarative intent only.
- [x] 3.3 Ensure contracts explicitly forbid VPN, TUN, kernel filtering, DPI, packet capture, zero-leak routing promises, concrete DNS clients, and proxy implementations.

## 4. Validation

- [x] 4.1 Add focused tests for policy persistence, deterministic evaluation, SSRF failures, provider gateway handoffs, invalidation events, and capability fallback behavior.
- [x] 4.2 Update runtime checker coverage for network policy profiles, provider assignments, evaluation outcomes, gateway handoffs, and forbidden system-routing behavior.
- [x] 4.3 Run `openspec validate "network-policy-contract" --strict`, `openspec validate --all`, `dart analyze`, focused tests, runtime checker, and automation boundary checker.
