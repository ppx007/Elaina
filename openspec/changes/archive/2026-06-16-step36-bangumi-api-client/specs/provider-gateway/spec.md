## ADDED Requirements

### Requirement: ProviderGateway SHALL govern concrete Bangumi API traffic
Concrete Bangumi API traffic SHALL be dispatched only from loader functions
owned by ProviderGateway requests under the registered Bangumi provider id.

#### Scenario: Concrete Bangumi subject lookup executes
- **WHEN** the concrete Bangumi client loads a subject from the API
- **THEN** the HTTP dispatch occurs inside a ProviderGateway request with the
  Bangumi provider id, deterministic subject request key, cache policy, and
  deduplication window

### Requirement: Bangumi concrete client tests SHALL avoid live network dependency
Concrete Bangumi client validation SHALL use injectable fake transport for
request and response assertions instead of depending on live Bangumi service
availability.

#### Scenario: Concrete client tests run offline
- **WHEN** Bangumi concrete client tests execute in CI or local validation
- **THEN** they verify request construction, headers, JSON mapping, and failure
  normalization through fake transport without external network access
