## ADDED Requirements

### Requirement: Network policy boundary SHALL cover WebView challenge and backfill traffic
The network policy boundary SHALL treat manual WebView challenge navigation and backfilled provider retries as provider-scoped traffic subject to SSRF protections, configured routing intent, platform capability reporting, redirect checks, and normalized security failures.

#### Scenario: Challenge origin is unsafe
- **WHEN** a manual challenge navigation targets or redirects to a private, loopback, link-local, disallowed-scheme, unsafe-redirect, or policy-prohibited address
- **THEN** network policy blocks the challenge flow before session artifacts can be captured

#### Scenario: Backfilled retry violates provider policy
- **WHEN** a provider retry with backfilled session artifacts targets a host blocked by provider-scoped network policy
- **THEN** network policy rejects the retry descriptor and reports a normalized security failure without exposing the artifact to transport code
