## ADDED Requirements

### Requirement: Bangumi provider runtime SHALL use deterministic request keys
Bangumi provider runtime operations SHALL construct provider request keys for subject lookup, subject search, episode lookup, session lookup, and progress sync without exposing concrete HTTP endpoint paths to Domain or UI layers.

#### Scenario: Subject metadata is looked up
- **WHEN** Bangumi subject metadata is requested through the runtime
- **THEN** the provider executes a ProviderGateway request under the Bangumi provider id with a deterministic subject request key

### Requirement: Bangumi runtime auth SHALL remain optional enrichment
Bangumi runtime auth and progress sync SHALL remain optional enrichment and MUST NOT be required for playback, subtitle parsing, subtitle rendering descriptors, Dandanplay matching, RSS, BT, online-rule runtime, or local media flows.

#### Scenario: Bangumi auth is absent
- **WHEN** the Bangumi auth provider reports no current session
- **THEN** Domain receives a normalized unauthenticated result and other non-Bangumi features remain outside the failure path

### Requirement: Bangumi runtime SHALL normalize gateway failures
Bangumi runtime provider implementations SHALL convert ProviderGateway failures into `AcgProviderFailureKind` values before returning results to Domain.

#### Scenario: Gateway throttles a Bangumi request
- **WHEN** ProviderGateway reports a throttled Bangumi request
- **THEN** the Bangumi runtime returns an `AcgProviderFailure` with throttled semantics instead of leaking gateway exceptions
