## ADDED Requirements

### Requirement: Home Bangumi search SHALL use anime heat ordering
Home Bangumi search SHALL request Bangumi anime subjects through the provider
contract using the API heat ordering so high-collection/popular subjects appear
before low-value literal matches.

#### Scenario: User searches Bangumi from the home page
- **WHEN** the provider builds a Bangumi subject search request for home search
- **THEN** the request body uses `sort=heat`
- **AND** the request body includes `filter.type=[2]`
- **AND** the request remains routed through ProviderGateway rather than UI-side
  HTTP or client-side catalog filtering
