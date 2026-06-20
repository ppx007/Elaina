## ADDED Requirements

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
