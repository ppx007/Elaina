## ADDED Requirements

### Requirement: ProviderGateway SHALL govern online rule source traffic
ProviderGateway SHALL govern online rule manifest updates and page retrieval with provider registration, rate policy, retry policy, request deduplication, cache validator propagation, negative-cache behavior, and normalized provider failures.

#### Scenario: Online rule page is retrieved
- **WHEN** the online rule runtime needs a page document for evaluation
- **THEN** the request is routed through ProviderGateway under the rule source provider identity rather than through source-owned transport logic
