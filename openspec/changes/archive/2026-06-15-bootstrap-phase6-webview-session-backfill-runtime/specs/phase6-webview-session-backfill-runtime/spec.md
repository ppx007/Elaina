## ADDED Requirements

### Requirement: WebView session backfill runtime SHALL provide bootstrap acceptance layer
The system SHALL define `WebViewSessionBackfillRuntimeBootstrap` that accepts a `WebViewSessionBackfillStore`, per-scope `WebViewSessionBackfill` contracts, per-scope `WebViewSessionCapabilityMatrix` values, an optional `CacheInvalidationBus`, and an optional clock to produce `WebViewSessionBackfillRuntime` instances.

#### Scenario: Bootstrap creates scoped runtime
- **WHEN** the bootstrap is constructed with store, scope-to-backfill map, and scope-to-capability map
- **THEN** `createRuntime()` returns a runtime that gates operations by scope and capability

### Requirement: WebView session backfill runtime SHALL expose typed action outcomes
The runtime SHALL return `WebViewSessionBackfillRuntimeActionResult<T>` for runtime operations with success, failed, unavailable, and disposed result states.

#### Scenario: Unsupported scope returns typed failure
- **WHEN** a scope lacks required WebView session backfill capability
- **THEN** the runtime returns a failed result with `capabilityUnsupported`

### Requirement: WebView session backfill runtime SHALL project restart state from storage
The runtime SHALL expose `WebViewSessionBackfillRuntimeRestartProjection` and `WebViewSessionBackfillRuntimeProjection` built from stored challenge requests, captured artifacts, latest backfill attempt, and capability state.

#### Scenario: Runtime restarts after manual challenge capture
- **WHEN** challenge, artifact, and attempt records already exist in storage
- **THEN** `snapshot()` returns a projection with replayable challenge, artifact, and attempt state without invoking a WebView

### Requirement: WebView session backfill runtime SHALL prepare same-origin retry descriptors only
The runtime SHALL prepare retry descriptors through the existing descriptor factory and MUST reject cross-origin or inactive artifact reuse.

#### Scenario: Cross-origin retry is rejected
- **WHEN** captured artifacts do not match the requested retry origin
- **THEN** `prepareRetry()` returns a typed runtime failure and records a rejected-origin backfill attempt

### Requirement: WebView session backfill runtime MUST remain manual-only
The runtime MUST NOT implement automatic captcha solving, challenge bypass, credential guessing, bot completion, headless automation, hidden browser interaction, shared profile cookie access, cross-origin reuse, concrete WebView plugins, Flutter widgets, diagnostics behavior, or network policy enforcement.

#### Scenario: Boundary checker scans runtime files
- **WHEN** the Step 28 checker scans runtime, tests, and tools
- **THEN** forbidden automation, browser plugin, UI, diagnostics, network policy, native, RSS, BT, and online-rule dependencies are absent
