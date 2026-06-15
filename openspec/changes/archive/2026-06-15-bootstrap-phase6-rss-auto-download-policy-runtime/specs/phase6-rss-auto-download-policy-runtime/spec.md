## ADDED Requirements

### Requirement: RSS auto-download policy runtime SHALL provide bootstrap acceptance layer
The system SHALL define `RssAutoDownloadPolicyRuntimeBootstrap` that accepts an RssAutoDownloadPolicyStore, per-scope DeterministicRssAutoDownloadPolicyEvaluator maps, per-scope RssAutomationCapabilityMatrix maps, optional RssAutomationHistoryStore, optional CacheInvalidationBus, and optional clock to produce RssAutoDownloadPolicyRuntime instances via createRuntime().

#### Scenario: Bootstrap creates runtime with policy store and capabilities
- **WHEN** RssAutoDownloadPolicyRuntimeBootstrap is constructed with a policy store, scope-to-evaluator map, and scope-to-capability map
- **THEN** calling createRuntime() returns an RssAutoDownloadPolicyRuntime that delegates to the per-scope evaluator and publishes events through the bus

### Requirement: RSS auto-download policy runtime SHALL provide typed scoped projections
The system SHALL expose RssAutoDownloadPolicyRuntimeProjection that combines current in-memory evaluation outcome, latest handoff outcome, latest failure with stored policy, evaluation, candidate, deduplication, and enqueue state to produce a restart-safe projection.

#### Scenario: Snapshot reads policy and evaluation from store after restart
- **WHEN** a runtime is created for a scope that has stored policy and evaluation records
- **THEN** snapshot() returns a projection reflecting the stored policy and latest evaluation kind without requiring in-memory evaluation

### Requirement: RSS auto-download policy runtime SHALL provide restart replay projection
The system SHALL define RssAutoDownloadPolicyRuntimeRestartProjection that reads the latest evaluation kind, latest candidate dedupe key, and latest enqueue state from storage so restart flows can restore automation state without re-evaluating feed items.

#### Scenario: Restart projection replays evaluation and enqueue state
- **WHEN** a runtime is created for a scope with existing stored evaluation, candidate, and enqueue records
- **THEN** the restart projection exposes the stored evaluation kind, candidate dedupe key, and enqueue state

### Requirement: RSS auto-download policy runtime SHALL gate disposed unavailable and unsupported states
The system SHALL gate all operations (snapshot, evaluate, handoff, disable, reenable) against disposed, unavailable, and unsupported-capability states, returning typed RssAutoDownloadPolicyRuntimeFailure outcomes. evaluate() additionally requires policyEvaluation capability; handoff() additionally requires btTaskHandoff capability.

#### Scenario: Disposed runtime rejects snapshot
- **WHEN** dispose() has been called on the runtime
- **THEN** snapshot() returns a disposed failure outcome

#### Scenario: Unavailable runtime rejects evaluate
- **WHEN** the runtime was constructed with RssAutoDownloadPolicyRuntime.unavailable()
- **THEN** evaluate() returns an unavailable failure outcome

#### Scenario: Unsupported scope evaluate returns capabilityUnsupported
- **WHEN** the scope has policyEvaluation capability marked unsupported
- **THEN** evaluate() returns a capabilityUnsupported failure outcome

#### Scenario: Unsupported scope handoff returns capabilityUnsupported
- **WHEN** the scope has btTaskHandoff capability marked unsupported
- **THEN** handoff() returns a capabilityUnsupported failure outcome

### Requirement: RSS auto-download policy runtime MUST remain scoped to Step 26
The system MUST keep concrete torrent engines, libtorrent bindings, FeedFetcher, FeedParser, duplicate RSS engine instances, online source rule runtimes, WebView challenge handling, captcha solving, DNS/network policy behavior, diagnostics center actions, mandatory automation startup, yuc.wiki special-casing, and Flutter rendering outside the RSS auto-download policy runtime slice.

#### Scenario: Boundary checker rejects out-of-scope dependencies
- **WHEN** boundary checks scan Step 26 runtime, test, and checker files
- **THEN** no concrete torrent engine, FeedFetcher, FeedParser, libtorrent, WebView, captcha, DNS client, proxy server, diagnostics center, online rule runtime, or Flutter widget import is found
