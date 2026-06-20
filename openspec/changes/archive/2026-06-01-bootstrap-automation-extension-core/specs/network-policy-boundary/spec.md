## ADDED Requirements

### Requirement: Network policy SHALL be provider scoped
The system SHALL define network policies as provider-scoped ordered rules that apply to provider, feed, and rule-source traffic routed through ProviderGateway.

#### Scenario: Provider request is created
- **WHEN** a provider-facing request is prepared
- **THEN** ProviderGateway evaluates the applicable provider network policy before dispatching the request

### Requirement: Network policy SHALL define declarative routing intent
The system SHALL define declarative policy actions for system DNS, configured DNS resolver intent, proxy tag intent, direct routing intent, block decisions, fallback behavior, and audit metadata.

#### Scenario: Domain matches proxy policy
- **WHEN** a request domain matches a proxy-tag policy rule
- **THEN** the network policy result includes proxy routing intent and audit metadata without exposing proxy implementation details to the provider

### Requirement: Network policy MUST enforce SSRF protections
The system MUST define SSRF protection checks for disallowed schemes, loopback addresses, link-local addresses, private network ranges, unsafe redirects, and policy-prohibited hosts before provider traffic is dispatched.

#### Scenario: Rule source resolves to loopback
- **WHEN** a rule-source request targets or redirects to a loopback address
- **THEN** network policy blocks the request and reports a normalized security failure

### Requirement: Network policy SHALL report platform capability limits
The system SHALL expose network policy support and limitations through capability contracts because DNS, proxy, and background networking behavior differ by platform.

#### Scenario: Platform cannot enforce configured DNS intent
- **WHEN** the current platform cannot enforce a configured DNS policy for provider traffic
- **THEN** the capability contract reports the limitation and the policy falls back to system DNS unless the rule requires blocking

### Requirement: Network policy MUST NOT claim system-wide routing control
The system MUST model policy enforcement as app-level provider traffic governance and MUST NOT promise VPN, TUN, kernel filtering, DPI, or zero-leak system-wide routing behavior.

#### Scenario: User configures provider policy
- **WHEN** a provider policy is configured
- **THEN** the policy applies only to Elaina-managed provider traffic and not to unrelated system traffic
