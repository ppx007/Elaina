# provider-gateway Specification

## Purpose
TBD - created by archiving change bootstrap-phase-0-foundation. Update Purpose after archive.
## Requirements
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

### Requirement: Providers MUST register rate policies
Each provider integration MUST register its rate policy with `ProviderGateway` before issuing provider-facing requests through the gateway.

#### Scenario: A provider is registered
- **WHEN** a provider integration is added to the system
- **THEN** it declares the rate policy that `ProviderGateway` will enforce for that provider's outbound traffic

### Requirement: Provider failures SHALL use normalized semantics
The system SHALL expose provider-facing failures, including feed fetch failures, through normalized gateway semantics so higher layers can reason about retryable, throttled, cached-miss, and terminal failure outcomes consistently.

#### Scenario: A provider returns a transient failure
- **WHEN** an outbound provider request fails with a retryable condition
- **THEN** the gateway reports the failure using a normalized classification that allows callers and diagnostics to respond consistently

### Requirement: ProviderGateway SHALL govern online rule source traffic
ProviderGateway SHALL govern online rule manifest updates and page retrieval with provider registration, rate policy, retry policy, request deduplication, cache validator propagation, negative-cache behavior, and normalized provider failures.

#### Scenario: Online rule page is retrieved
- **WHEN** the online rule runtime needs a page document for evaluation
- **THEN** the request is routed through ProviderGateway under the rule source provider identity rather than through source-owned transport logic

### Requirement: ProviderGateway SHALL govern WebView session backfill retries
ProviderGateway SHALL govern provider retries that use WebView backfilled session artifacts with provider registration, rate policy, retry policy, request deduplication, cache validator propagation, negative-cache behavior, scoped session state, and normalized provider failures.

#### Scenario: Provider retries after manual challenge completion
- **WHEN** a provider request is retried using a same-origin captured session artifact
- **THEN** the retry flows through ProviderGateway under the provider identity rather than through direct provider-owned transport or global browser state

#### Scenario: Backfilled retry fails
- **WHEN** a retry using captured session state fails, expires, or is rejected by policy
- **THEN** ProviderGateway reports a normalized provider failure that callers and diagnostics can classify consistently

