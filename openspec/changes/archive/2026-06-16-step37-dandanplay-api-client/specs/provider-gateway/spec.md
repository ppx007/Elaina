## ADDED Requirements

### Requirement: ProviderGateway SHALL govern concrete Dandanplay API traffic
Concrete Dandanplay API traffic SHALL be dispatched only from loader functions
owned by ProviderGateway requests under the registered Dandanplay provider id.

#### Scenario: Concrete Dandanplay match executes
- **WHEN** the concrete Dandanplay client matches local media or retrieves
  comments from the API
- **THEN** HTTP dispatch occurs inside a ProviderGateway request with the
  Dandanplay provider id, deterministic request key, cache policy, and
  deduplication window

### Requirement: Dandanplay concrete client tests SHALL avoid live network dependency
Concrete Dandanplay client validation SHALL use injectable fake transport for
request and response assertions instead of depending on live Dandanplay service
availability.

#### Scenario: Concrete client tests run offline
- **WHEN** Dandanplay concrete client tests execute in CI or local validation
- **THEN** they verify request construction, headers, JSON mapping, and failure
  normalization through fake transport without external network access
