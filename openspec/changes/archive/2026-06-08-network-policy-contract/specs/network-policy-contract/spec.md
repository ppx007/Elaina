## ADDED Requirements

### Requirement: Network policy contract SHALL define provider-scoped policies
The system SHALL define network policy profiles as provider-scoped contracts with ordered rules, fallback behavior, audit metadata, and explicit provider assignment state.

#### Scenario: Provider policy is registered
- **WHEN** a provider, RSS source, online rule source, or WebView challenge scope registers network governance
- **THEN** the system records a provider-scoped policy profile rather than applying global routing state

### Requirement: Network policy contract SHALL define declarative routing intents
The system SHALL represent system DNS, configured DNS, DoH resolver intent, DoT resolver intent, proxy tag intent, direct routing intent, block decisions, fallback behavior, and audit metadata as declarative policy outcomes.

#### Scenario: Rule selects DoH resolver intent
- **WHEN** a provider-scoped domain rule matches a request and selects DoH resolver intent
- **THEN** the policy decision records the resolver intent and audit metadata without creating or invoking a concrete DoH client

### Requirement: Network policy contract SHALL normalize SSRF failures
The system SHALL normalize security failures for disallowed schemes, loopback addresses, link-local addresses, private network ranges, unsafe redirects, provider-blocked hosts, and unsupported policy capability.

#### Scenario: Request targets private network range
- **WHEN** a provider-scoped request or redirect is classified as private network traffic
- **THEN** the policy decision blocks the request and returns a normalized private-network failure before provider dispatch

### Requirement: Network policy contract SHALL expose deterministic evaluation scaffolding
The system SHALL expose deterministic policy evaluation contracts for exact host, domain suffix, wildcard host, and CIDR-style matcher intent without requiring platform DNS resolution.

#### Scenario: Domain suffix rule matches
- **WHEN** a request host matches a provider-scoped domain suffix rule
- **THEN** the deterministic evaluator returns the matching rule decision, action intent, fallback metadata, and audit label

### Requirement: Network policy contract SHALL report capability limits
The system SHALL expose capability contracts for configured DNS intent, DoH intent, DoT intent, proxy intent, redirect validation, SSRF guard, and background network policy support.

#### Scenario: Platform cannot enforce DoT intent
- **WHEN** a matching rule requests DoT resolver intent on a platform that does not support it
- **THEN** the policy decision reports an unsupported capability or falls back according to the policy's declared fallback behavior

### Requirement: Network policy contract MUST NOT claim system-wide routing control
The system MUST NOT define VPN, TUN, kernel filtering, DPI, packet capture, or zero-leak system-wide routing behavior as part of the network policy contract.

#### Scenario: Policy is evaluated for provider traffic
- **WHEN** a network policy decision is produced
- **THEN** the decision applies only to Celesteria-managed provider traffic and not unrelated system traffic
