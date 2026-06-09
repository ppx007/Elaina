## ADDED Requirements

### Requirement: ProviderGateway SHALL support Bangumi runtime request governance
ProviderGateway SHALL support Bangumi runtime requests for subject lookup, subject search, episode lookup, session lookup, and progress sync through typed provider request keys and existing cache policy controls.

#### Scenario: Bangumi runtime executes a gateway request
- **WHEN** the Bangumi runtime issues a metadata or progress request
- **THEN** ProviderGateway receives the Bangumi provider id, deterministic request key, cache policy, and loader function without Domain or UI bypassing provider governance

### Requirement: ProviderGateway registration SHALL preserve Bangumi provider policy
ProviderGateway registration SHALL preserve Bangumi provider rate, retry, and negative-cache policy before Bangumi runtime requests execute.

#### Scenario: Bangumi runtime starts
- **WHEN** the Bangumi runtime bootstrap initializes
- **THEN** it registers the Bangumi provider policy before executing subject, episode, session, or progress requests
