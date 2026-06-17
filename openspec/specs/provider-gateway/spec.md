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

### Requirement: ProviderGateway SHALL hand provider traffic to network policy before dispatch
ProviderGateway SHALL prepare provider-scoped network policy handoff descriptors before dispatching provider, RSS, online rule, or WebView backfill requests.

#### Scenario: Provider request is ready for dispatch
- **WHEN** ProviderGateway has registered provider identity, rate policy, retry policy, cache policy, and request key
- **THEN** it exposes a network policy handoff descriptor so Network-layer policy evaluation can allow, block, or annotate the request before transport dispatch

#### Scenario: Network policy blocks provider traffic
- **WHEN** network policy rejects a provider request because of SSRF, unsafe redirect, blocked host, or unsupported required capability
- **THEN** ProviderGateway reports a normalized provider failure instead of dispatching the request

### Requirement: ProviderGateway SHALL expose diagnostics correlation metadata
ProviderGateway SHALL expose diagnostics-safe correlation metadata for provider-facing request failures, cache hits, negative-cache outcomes, throttling, retry exhaustion, and network policy blocks without granting diagnostics dispatch or retry control.

#### Scenario: Provider request fails after retries
- **WHEN** ProviderGateway reports a retryable, throttled, cached-miss, terminal, or network-policy-blocked provider failure
- **THEN** diagnostics can record the failure classification, provider identity, request key, cache policy, and correlation identity without redispatching or mutating the provider request

### Requirement: ProviderGateway bootstrap SHALL preserve provider request contracts
The system SHALL provide deterministic ProviderGateway bootstrap scaffolding that preserves provider identity, request keys, cache policy, registration metadata, storage access, and typed failure semantics without owning concrete network dispatch.

#### Scenario: Provider request executes through bootstrap gateway
- **WHEN** a registered provider request supplies a loader function and cache policy
- **THEN** the bootstrap ProviderGateway returns a typed response or typed provider failure while preserving the original provider id, request key, cache policy, and storage foundation access

### Requirement: ProviderGateway bootstrap SHALL bound request de-duplication behavior
The bootstrap ProviderGateway SHALL expose deterministic request de-duplication boundaries without adding retry scheduling, HTTP clients, background queues, or provider-specific transport behavior.

#### Scenario: Duplicate request is evaluated
- **WHEN** two ProviderGateway requests share the same provider request key inside the configured de-duplication boundary
- **THEN** the bootstrap preserves a deterministic request outcome without dispatching provider-specific network transport or mutating provider state outside registration metadata

### Requirement: ProviderGateway SHALL support Bangumi runtime request governance
ProviderGateway SHALL support Bangumi runtime requests for subject lookup, subject search, episode lookup, session lookup, and progress sync through typed provider request keys and existing cache policy controls.

#### Scenario: Bangumi runtime executes a gateway request
- **WHEN** the Bangumi runtime issues a metadata or progress request
- **THEN** ProviderGateway receives the Bangumi provider id, deterministic request key, cache policy, and loader function without Domain or UI bypassing provider governance

### Requirement: ProviderGateway registration SHALL preserve Bangumi provider policy
ProviderGateway registration SHALL preserve Bangumi provider rate, retry, and negative-cache policy before Bangumi runtime requests execute.

#### Scenario: Bangumi runtime starts
- **WHEN** the Bangumi runtime bootstrap initializes
- **THEN** it registers the Bangumi provider policy before executing subject, episode, session, or progress requests

### Requirement: ProviderGateway SHALL support Dandanplay runtime request governance
ProviderGateway SHALL support Dandanplay runtime requests for local media match, subject search, comment retrieval, and comment posting through typed provider request keys and existing cache policy controls.

#### Scenario: Dandanplay runtime executes a gateway request
- **WHEN** the Dandanplay runtime issues a match, search, comments, or post-comment request
- **THEN** ProviderGateway receives the Dandanplay provider id, deterministic request key, cache policy, and loader function without Domain, Playback, or UI bypassing provider governance

### Requirement: ProviderGateway registration SHALL preserve Dandanplay provider policy
ProviderGateway registration SHALL preserve Dandanplay provider rate, retry, and negative-cache policy before Dandanplay runtime requests execute.

#### Scenario: Dandanplay runtime starts
- **WHEN** the Dandanplay runtime bootstrap initializes
- **THEN** it registers the Dandanplay provider policy before executing match, search, comments, or post-comment requests

### Requirement: Provider fallback sentinels SHALL use named gateway policies
Unavailable provider sentinels SHALL express gateway registration policy through
named constants or helpers so sentinel rate and retry behavior is not encoded as
duplicated inline numeric values.

#### Scenario: Optional provider is unavailable
- **WHEN** a runtime composes an unavailable provider placeholder
- **THEN** the placeholder registers with named sentinel rate and retry policy
  values while still returning normalized unavailable failures for provider
  operations

### Requirement: ProviderGateway SHALL govern concrete Bangumi API traffic
Concrete Bangumi API traffic SHALL be dispatched only from loader functions
owned by ProviderGateway requests under the registered Bangumi provider id.

#### Scenario: Concrete Bangumi subject lookup executes
- **WHEN** the concrete Bangumi client loads a subject from the API
- **THEN** the HTTP dispatch occurs inside a ProviderGateway request with the
  Bangumi provider id, deterministic subject request key, cache policy, and
  deduplication window

### Requirement: Bangumi concrete client tests SHALL avoid live network dependency
Concrete Bangumi client validation SHALL use injectable fake transport for
request and response assertions instead of depending on live Bangumi service
availability.

#### Scenario: Concrete client tests run offline
- **WHEN** Bangumi concrete client tests execute in CI or local validation
- **THEN** they verify request construction, headers, JSON mapping, and failure
  normalization through fake transport without external network access

### Requirement: ProviderGateway SHALL govern concrete Dandanplay API traffic
Concrete Dandanplay API traffic SHALL be dispatched only from loader functions
owned by ProviderGateway requests under the registered Dandanplay provider id.

#### Scenario: Concrete Dandanplay match executes
- **WHEN** the concrete Dandanplay client matches local media or retrieves
  comments from the API
- **THEN** HTTP dispatch occurs inside a ProviderGateway request with the
  Dandanplay provider id, deterministic request key, cache policy, and
  deduplication window

### Requirement: Dandanplay concrete client tests SHALL avoid live network dependency
Concrete Dandanplay client validation SHALL use injectable fake transport for
request and response assertions instead of depending on live Dandanplay service
availability.

#### Scenario: Concrete client tests run offline
- **WHEN** Dandanplay concrete client tests execute in CI or local validation
- **THEN** they verify request construction, headers, JSON mapping, and failure
  normalization through fake transport without external network access

### Requirement: ProviderGateway SHALL govern concrete OpenSubtitles traffic
Concrete OpenSubtitles API traffic SHALL be dispatched only from loader
functions owned by ProviderGateway requests under the OpenSubtitles provider
id.

#### Scenario: Concrete OpenSubtitles search executes
- **WHEN** the concrete provider searches subtitles or retrieves subtitle
  content
- **THEN** HTTP dispatch occurs inside a ProviderGateway request with the
  OpenSubtitles provider id, deterministic request key, cache policy, and
  deduplication window

### Requirement: OpenSubtitles concrete provider tests SHALL avoid live network dependency
Concrete OpenSubtitles provider validation SHALL use injectable fake transport
for request and response assertions instead of depending on live
OpenSubtitles service availability.

#### Scenario: Concrete provider tests run offline
- **WHEN** OpenSubtitles provider tests execute in CI or local validation
- **THEN** they verify request construction, headers, JSON mapping, and failure
  normalization through fake transport without external network access

### Requirement: ACG smoke gate SHALL preserve provider gateway semantics
The ACG smoke gate SHALL reuse existing provider runtimes and ProviderGateway
requests rather than calling provider HTTP clients directly or bypassing
registration, request keys, cache policies, deduplication, and typed failures.

#### Scenario: ACG smoke gate invokes provider enrichment
- **WHEN** the smoke gate resolves Bangumi, Dandanplay, and subtitle provider
  enrichment
- **THEN** provider operations still flow through the existing provider runtime
  gateway/cache surfaces and can be validated without live network access

