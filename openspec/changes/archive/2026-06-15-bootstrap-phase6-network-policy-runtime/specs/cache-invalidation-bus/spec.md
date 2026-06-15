## ADDED Requirements

### Requirement: Cache invalidation bus SHALL support network policy runtime events
The cache invalidation bus SHALL carry network policy runtime events for provider assignment changes, evaluation outcomes, block decisions, and capability changes using the existing typed network policy event payloads.

#### Scenario: Runtime assigns provider policy
- **WHEN** the runtime records a provider policy assignment
- **THEN** `NetworkPolicyProviderAssignmentChanged` is published through the bus after the assignment is stored

#### Scenario: Runtime evaluates provider policy
- **WHEN** the runtime records a policy evaluation outcome
- **THEN** `NetworkPolicyEvaluationOutcomeRecorded` is published through the bus after the evaluation snapshot is stored

#### Scenario: Runtime records blocked decision
- **WHEN** the runtime records a blocked policy decision
- **THEN** `NetworkPolicyBlockDecisionRecorded` is published through the bus after the block outcome is stored

#### Scenario: Runtime records capability state
- **WHEN** the runtime records support or lack of support for a network policy capability
- **THEN** `NetworkPolicyCapabilityChanged` is published through the bus without directly mutating Gateway, Network, UI, or diagnostics state
