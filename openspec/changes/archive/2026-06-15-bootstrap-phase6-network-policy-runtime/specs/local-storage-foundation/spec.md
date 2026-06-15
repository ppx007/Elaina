## ADDED Requirements

### Requirement: Local storage foundation SHALL support network policy runtime replay
The local storage foundation SHALL allow the network policy runtime to persist and replay provider policy assignments, evaluation snapshots, block outcomes, and capability state through existing `NetworkPolicyStore` contracts.

#### Scenario: Runtime rebuilds projection from store after restart
- **WHEN** a new runtime instance is created for a provider scope with stored assignment, evaluation, block, and capability records
- **THEN** the runtime projection reads those records from storage without requiring a concrete resolver, proxy, provider dispatch, diagnostics, UI, or platform network plugin

#### Scenario: Runtime records evaluation before projection
- **WHEN** runtime evaluation returns an allow, fallback, proxy, DNS, direct, or block decision
- **THEN** the runtime records the evaluation through the store before exposing the updated projection or publishing invalidation
