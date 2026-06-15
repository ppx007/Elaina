## ADDED Requirements

### Requirement: Network policy contract SHALL expose runtime action results
The network policy contract SHALL support a runtime acceptance layer with typed action results, scoped projections, restart projections, unavailable/disposed gates, unsupported-capability gates, and compact runtime failures over the deterministic policy evaluator.

#### Scenario: Runtime evaluation returns typed projection
- **WHEN** a provider-scoped request is evaluated through the runtime acceptance layer
- **THEN** the caller receives a typed action result containing either a policy projection or a runtime failure without invoking a concrete resolver, proxy, or transport client

### Requirement: Network policy contract SHALL preserve normalized block details through runtime evaluation
The runtime acceptance layer SHALL preserve normalized `NetworkPolicyBlocked` details and stored block outcomes while keeping runtime failure kinds compact.

#### Scenario: SSRF guard blocks private traffic
- **WHEN** runtime evaluation blocks a request because the deterministic evaluator reports a private-network SSRF failure
- **THEN** the projection and stored block outcome preserve that normalized failure detail while the runtime surface remains provider-scoped and declarative
