## ADDED Requirements

### Requirement: RSS auto-download policy contract SHALL expose typed runtime-level outcomes
The system SHALL define RssAutoDownloadPolicyRuntimeActionResult<T> with success/failed/unavailable/disposed states and RssAutoDownloadPolicyRuntimeFailureKind (capabilityUnsupported, unavailable, disposed, policyNotFound, policyDisabled, automationDisabled, invalidMatcher, unsupportedSource, historyUnavailable, enqueueUnavailable, deduplicated) so consuming code can inspect runtime-level outcomes without depending on evaluator internals or concrete download adapter exceptions.

#### Scenario: Runtime action result distinguishes success from failure
- **WHEN** the runtime processes an evaluate or handoff request
- **THEN** the returned RssAutoDownloadPolicyRuntimeActionResult<T> exposes isSuccess and typed failure kinds

### Requirement: RSS auto-download policy contract MUST remain scoped to Step 26
The system MUST keep concrete torrent engines, libtorrent, FeedFetcher, FeedParser, duplicate RSS engine instances, online source rule runtimes, WebView challenge flow, captcha solving, DNS/network policy, diagnostics actions, mandatory automation startup, yuc.wiki special-casing, and Flutter widgets outside the Step 26 runtime. The runtime acceptance layer SHALL enforce this boundary by rejecting any import or dependency on concrete engine, fetcher, parser, native, UI, or out-of-slice modules.

#### Scenario: Step 26 runtime boundary is enforced
- **WHEN** the runtime, tests, and checkers are scanned for boundary violations
- **THEN** no libtorrent, FeedFetcher, FeedParser, concrete torrent engine, WebView, captcha, DNS client, proxy server, diagnostics center, online rule runtime, or Flutter widget dependency is found
