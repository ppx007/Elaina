## ADDED Requirements

### Requirement: Network policy mutations SHALL publish invalidation events
The system SHALL publish explicit invalidation events when network policy profiles change, provider assignments change, policy rules change, evaluation outcomes are recorded, block decisions occur, or network policy capability state changes.

#### Scenario: Provider policy assignment changes
- **WHEN** a provider scope is assigned to a different network policy profile
- **THEN** a network policy invalidation event is published so Gateway, Network, and future diagnostics consumers can refresh derived state without direct cross-module mutation

#### Scenario: Network policy blocks traffic
- **WHEN** a provider-scoped request is blocked by network policy
- **THEN** a network policy evaluation event is published with provider scope, target URI metadata, and normalized failure kind
