## ADDED Requirements

### Requirement: ProviderGateway SHALL expose diagnostics correlation metadata
ProviderGateway SHALL expose diagnostics-safe correlation metadata for provider-facing request failures, cache hits, negative-cache outcomes, throttling, retry exhaustion, and network policy blocks without granting diagnostics dispatch or retry control.

#### Scenario: Provider request fails after retries
- **WHEN** ProviderGateway reports a retryable, throttled, cached-miss, terminal, or network-policy-blocked provider failure
- **THEN** diagnostics can record the failure classification, provider identity, request key, cache policy, and correlation identity without redispatching or mutating the provider request
