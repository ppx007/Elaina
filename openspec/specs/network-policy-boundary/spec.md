# network-policy-boundary Specification

## Purpose
TBD - created by archiving change bootstrap-automation-extension-core. Update Purpose after archive.
## Requirements
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

### Requirement: Network policy boundary SHALL cover online rule source traffic
The network policy boundary SHALL treat online rule manifest updates and page retrieval as provider-scoped traffic subject to SSRF protections, configured routing intent, platform capability reporting, and normalized security failures.

#### Scenario: Online rule page resolves to a private address
- **WHEN** a rule-source page retrieval targets or redirects to a private, loopback, link-local, disallowed-scheme, or policy-prohibited address
- **THEN** network policy blocks the request and reports a normalized failure before evaluation receives a document

### Requirement: Network policy boundary SHALL cover WebView challenge and backfill traffic
The network policy boundary SHALL treat manual WebView challenge navigation and backfilled provider retries as provider-scoped traffic subject to SSRF protections, configured routing intent, platform capability reporting, redirect checks, and normalized security failures.

#### Scenario: Challenge origin is unsafe
- **WHEN** a manual challenge navigation targets or redirects to a private, loopback, link-local, disallowed-scheme, unsafe-redirect, or policy-prohibited address
- **THEN** network policy blocks the challenge flow before session artifacts can be captured

#### Scenario: Backfilled retry violates provider policy
- **WHEN** a provider retry with backfilled session artifacts targets a host blocked by provider-scoped network policy
- **THEN** network policy rejects the retry descriptor and reports a normalized security failure without exposing the artifact to transport code

### Requirement: Network policy boundary SHALL cover provider-scoped DNS and proxy intent
The network policy boundary SHALL treat per-domain DNS, DoH, DoT, direct routing, proxy tag, block, fallback, and audit behavior as provider-scoped declarative intent for Elaina-managed provider traffic.

#### Scenario: Provider request matches resolver policy
- **WHEN** a provider-facing request matches a provider-scoped DNS, DoH, DoT, direct, proxy, or block rule
- **THEN** the boundary returns a declarative policy decision without exposing concrete resolver, proxy, VPN, or system-routing implementation details

### Requirement: Network policy boundary SHALL preserve safe fallback behavior
The network policy boundary SHALL define fallback behavior for unsupported DNS/proxy capabilities, defaulting to system DNS unless the matched rule or platform policy requires blocking.

#### Scenario: Configured resolver unsupported
- **WHEN** a policy requests configured resolver intent on a platform that cannot enforce it
- **THEN** the boundary reports the capability limit and either falls back to system DNS or blocks according to the policy's fallback behavior

### Requirement: Network policy boundary SHALL constrain the runtime acceptance layer
The network policy runtime acceptance layer SHALL remain a provider-scoped orchestration boundary over existing policy contracts, storage contracts, Gateway handoff value types, and cache invalidation events.

#### Scenario: Runtime evaluates provider traffic
- **WHEN** Gateway or Network code evaluates provider-scoped policy intent through the runtime
- **THEN** the runtime returns declarative allow/block/fallback/proxy/DNS intent without owning provider dispatch, DNS resolution, proxy transport, or system-wide routing

### Requirement: Network policy boundary MUST reject concrete networking leakage
Step 29 validation MUST reject runtime, test, and checker files that introduce concrete DNS clients, DoH clients, DoT clients, proxy clients, proxy servers, PAC parsers, VPN services, TUN interfaces, kernel filtering, DPI, packet capture, sockets, platform network plugins, UI widgets, native bindings, FFI, platform channels, or diagnostics implementation behavior.

#### Scenario: Boundary checker scans runtime slice
- **WHEN** Step 29 validation scans the network policy runtime files
- **THEN** forbidden concrete-networking, UI, native, platform, and diagnostics implementation terms fail validation before archive

