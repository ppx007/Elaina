## ADDED Requirements

### Requirement: Dandanplay provider runtime SHALL use deterministic request keys
Dandanplay provider runtime operations SHALL construct provider request keys for local media match, subject search, comment retrieval, and comment posting without exposing concrete HTTP endpoint paths to Domain, Playback, or UI layers.

#### Scenario: Local media match is requested
- **WHEN** Dandanplay local media matching is requested through the runtime
- **THEN** the provider executes a ProviderGateway request under the Dandanplay provider id with a deterministic match request key

### Requirement: Dandanplay comments SHALL remain provider-governed enrichment
Dandanplay comment retrieval and posting SHALL remain optional provider-governed enrichment and MUST NOT be required for playback, subtitle parsing, subtitle rendering descriptors, Bangumi metadata, RSS, BT, online-rule runtime, or local media flows.

#### Scenario: Dandanplay comments are unavailable
- **WHEN** the Dandanplay comment provider cannot retrieve comments for an episode
- **THEN** Domain receives a normalized provider result and other non-Dandanplay features remain outside the failure path

### Requirement: Dandanplay runtime SHALL normalize gateway failures
Dandanplay runtime provider implementations SHALL convert ProviderGateway failures into `AcgProviderFailureKind` values before returning results to Domain.

#### Scenario: Gateway throttles a Dandanplay comment request
- **WHEN** ProviderGateway reports a throttled Dandanplay comments request
- **THEN** the Dandanplay runtime returns an `AcgProviderFailure` with throttled semantics instead of leaking gateway exceptions
