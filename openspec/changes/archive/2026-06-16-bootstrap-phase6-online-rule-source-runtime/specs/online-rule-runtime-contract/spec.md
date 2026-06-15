## ADDED Requirements

### Requirement: Online rule runtime contract SHALL expose typed runtime-level outcomes
The system SHALL define OnlineRuleSourceRuntimeActionResult<T> with success/failed/unavailable/disposed states and OnlineRuleSourceRuntimeFailureKind (capabilityUnsupported, unavailable, disposed, manifestNotFound, manifestDisabled, manifestInvalid, evaluationFailed, sourceUnsupported) so consuming code can inspect runtime-level outcomes without depending on deterministic runtime internals or gateway exceptions.

#### Scenario: Runtime action result distinguishes success from failure
- **WHEN** the runtime processes a validate or evaluate request
- **THEN** the returned OnlineRuleSourceRuntimeActionResult<T> exposes isSuccess and typed failure kinds

### Requirement: Online rule runtime contract MUST remain scoped to Step 27
The system MUST keep gateway page retrieval, network client, WebView challenge flow, captcha solving, DNS/network policy, diagnostics actions, Flutter widgets, yuc.wiki special-casing, libtorrent bindings, registerSource, and refreshManifest outside the Step 27 runtime.

#### Scenario: Step 27 runtime boundary is enforced
- **WHEN** the runtime, tests, and checkers are scanned for boundary violations
- **THEN** no gateway client, network client, WebView, captcha, DNS client, proxy server, diagnostics center, Flutter widget, libtorrent, registerSource, or refreshManifest dependency is found
