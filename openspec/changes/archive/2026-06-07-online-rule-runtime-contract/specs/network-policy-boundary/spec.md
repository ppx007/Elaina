## ADDED Requirements

### Requirement: Network policy boundary SHALL cover online rule source traffic
The network policy boundary SHALL treat online rule manifest updates and page retrieval as provider-scoped traffic subject to SSRF protections, configured routing intent, platform capability reporting, and normalized security failures.

#### Scenario: Online rule page resolves to a private address
- **WHEN** a rule-source page retrieval targets or redirects to a private, loopback, link-local, disallowed-scheme, or policy-prohibited address
- **THEN** network policy blocks the request and reports a normalized failure before evaluation receives a document
