## ADDED Requirements

### Requirement: ProviderGateway SHALL govern WebView session backfill retries
ProviderGateway SHALL govern provider retries that use WebView backfilled session artifacts with provider registration, rate policy, retry policy, request deduplication, cache validator propagation, negative-cache behavior, scoped session state, and normalized provider failures.

#### Scenario: Provider retries after manual challenge completion
- **WHEN** a provider request is retried using a same-origin captured session artifact
- **THEN** the retry flows through ProviderGateway under the provider identity rather than through direct provider-owned transport or global browser state

#### Scenario: Backfilled retry fails
- **WHEN** a retry using captured session state fails, expires, or is rejected by policy
- **THEN** ProviderGateway reports a normalized provider failure that callers and diagnostics can classify consistently
