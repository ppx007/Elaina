## ADDED Requirements

### Requirement: Home search SHALL use Bangumi provider contracts
Home search SHALL resolve Bangumi subject suggestions through provider contracts
and ProviderGateway rather than through direct UI HTTP calls.

#### Scenario: User types a search query
- **WHEN** the home search surface requests Bangumi suggestions
- **THEN** the request is routed through the Bangumi provider search contract and
  returns normalized domain search items
