## ADDED Requirements

### Requirement: ProviderGateway SHALL support Dandanplay runtime request governance
ProviderGateway SHALL support Dandanplay runtime requests for local media match, subject search, comment retrieval, and comment posting through typed provider request keys and existing cache policy controls.

#### Scenario: Dandanplay runtime executes a gateway request
- **WHEN** the Dandanplay runtime issues a match, search, comments, or post-comment request
- **THEN** ProviderGateway receives the Dandanplay provider id, deterministic request key, cache policy, and loader function without Domain, Playback, or UI bypassing provider governance

### Requirement: ProviderGateway registration SHALL preserve Dandanplay provider policy
ProviderGateway registration SHALL preserve Dandanplay provider rate, retry, and negative-cache policy before Dandanplay runtime requests execute.

#### Scenario: Dandanplay runtime starts
- **WHEN** the Dandanplay runtime bootstrap initializes
- **THEN** it registers the Dandanplay provider policy before executing match, search, comments, or post-comment requests
