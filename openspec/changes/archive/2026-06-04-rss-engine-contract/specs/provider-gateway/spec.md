## MODIFIED Requirements

### Requirement: Provider traffic SHALL route through ProviderGateway
The system SHALL require external provider-facing requests, including RSS and Atom feed fetches, to pass through `ProviderGateway` rather than allowing each provider integration to define its own isolated networking governance path.

#### Scenario: A new provider is integrated
- **WHEN** a future Bangumi, subtitle, RSS, or rule-source provider needs outbound requests
- **THEN** the provider uses `ProviderGateway` as its request entry point

### Requirement: ProviderGateway MUST enforce shared request governance
`ProviderGateway` MUST provide request deduplication, rate limiting, retry scheduling, HTTP-cache hooks, cache validator propagation, and negative-cache behavior as shared gateway responsibilities.

#### Scenario: Repeated provider lookups occur under load
- **WHEN** multiple equivalent requests target the same provider resource within a deduplication window
- **THEN** the gateway coalesces the work and applies the provider's registered rate policy and retry behavior

### Requirement: Provider failures SHALL use normalized semantics
The system SHALL expose provider-facing failures, including feed fetch failures, through normalized gateway semantics so higher layers can reason about retryable, throttled, cached-miss, and terminal failure outcomes consistently.

#### Scenario: A provider returns a transient failure
- **WHEN** an outbound provider request fails with a retryable condition
- **THEN** the gateway reports the failure using a normalized classification that allows callers and diagnostics to respond consistently
