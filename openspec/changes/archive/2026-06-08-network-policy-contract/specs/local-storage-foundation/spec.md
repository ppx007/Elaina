## ADDED Requirements

### Requirement: Storage foundation SHALL expose network policy persistence contracts
The system SHALL expose storage-backed contracts for network policy profiles, ordered policy rules, provider policy assignments, policy evaluation snapshots, normalized block outcomes, and network policy capability state.

#### Scenario: Network policy state survives restart
- **WHEN** provider-scoped network policies, rules, assignments, evaluations, block outcomes, or capability state are written to Storage
- **THEN** later Gateway and Network flows can restore policy state without direct UI, provider, resolver, proxy, platform network plugin, or database coupling

#### Scenario: Evaluation outcome is recorded
- **WHEN** a provider-scoped network policy decision allows, annotates, falls back, or blocks a request
- **THEN** Storage records the evaluation snapshot for later diagnostics without granting diagnostics control over network behavior
