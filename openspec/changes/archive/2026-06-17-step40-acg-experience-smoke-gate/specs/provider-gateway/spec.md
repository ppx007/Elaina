## ADDED Requirements

### Requirement: ACG smoke gate SHALL preserve provider gateway semantics
The ACG smoke gate SHALL reuse existing provider runtimes and ProviderGateway
requests rather than calling provider HTTP clients directly or bypassing
registration, request keys, cache policies, deduplication, and typed failures.

#### Scenario: ACG smoke gate invokes provider enrichment
- **WHEN** the smoke gate resolves Bangumi, Dandanplay, and subtitle provider
  enrichment
- **THEN** provider operations still flow through the existing provider runtime
  gateway/cache surfaces and can be validated without live network access
