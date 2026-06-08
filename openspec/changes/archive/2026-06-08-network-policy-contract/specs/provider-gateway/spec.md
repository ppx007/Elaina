## ADDED Requirements

### Requirement: ProviderGateway SHALL hand provider traffic to network policy before dispatch
ProviderGateway SHALL prepare provider-scoped network policy handoff descriptors before dispatching provider, RSS, online rule, or WebView backfill requests.

#### Scenario: Provider request is ready for dispatch
- **WHEN** ProviderGateway has registered provider identity, rate policy, retry policy, cache policy, and request key
- **THEN** it exposes a network policy handoff descriptor so Network-layer policy evaluation can allow, block, or annotate the request before transport dispatch

#### Scenario: Network policy blocks provider traffic
- **WHEN** network policy rejects a provider request because of SSRF, unsafe redirect, blocked host, or unsupported required capability
- **THEN** ProviderGateway reports a normalized provider failure instead of dispatching the request
