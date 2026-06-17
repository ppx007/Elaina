# phase6-online-rule-source-runtime Specification

## Purpose
Runtime acceptance layer for online rule source — bootstrap, scoped projections, typed outcomes, restart replay, disable/reenable, and capability gates wrapping DeterministicOnlineRuleRuntime.
## Requirements
### Requirement: Online rule source runtime SHALL provide bootstrap acceptance layer
The system SHALL define `OnlineRuleSourceRuntimeBootstrap` that accepts an OnlineRuleRuntimeStore, per-scope DeterministicOnlineRuleRuntime maps, per-scope OnlineRuleCapabilityMatrix maps, and optional CacheInvalidationBus to produce OnlineRuleSourceRuntime instances via createRuntime(). No clock parameter.

#### Scenario: Bootstrap creates runtime with store and capabilities
- **WHEN** OnlineRuleSourceRuntimeBootstrap is constructed with a store, scope-to-runtime map, and scope-to-capability map
- **THEN** calling createRuntime() returns an OnlineRuleSourceRuntime that delegates to the per-scope deterministic runtime and publishes events through the bus

### Requirement: Online rule source runtime SHALL provide typed scoped projections
The system SHALL expose OnlineRuleSourceRuntimeProjection that reads manifest displayName, version, validationState from store, latest evaluation target/state from store, and latest evaluation outcome, normalized output, failure from in-memory state. Embeds RestartProjection.

#### Scenario: Snapshot reads manifest and evaluation from store after restart
- **WHEN** a runtime is created for a scope that has stored manifest and evaluation records
- **THEN** snapshot() returns a projection reflecting the stored manifest and latest evaluation state without requiring in-memory evaluation

### Requirement: Online rule source runtime SHALL provide restart replay projection
The system SHALL define OnlineRuleSourceRuntimeRestartProjection that reads sourceId, manifestValidationState, latestEvaluationTarget, and latestEvaluationState from storage so restart flows can restore online rule state without re-evaluating documents.

#### Scenario: Restart projection replays evaluation and manifest state
- **WHEN** a runtime is created for a scope with existing stored manifest and evaluation records
- **THEN** the restart projection exposes the stored validation state and latest evaluation target and state

### Requirement: Online rule source runtime SHALL gate disposed unavailable and unsupported states
The system SHALL gate all operations against disposed, unavailable, and unsupported-capability states, returning typed OnlineRuleSourceRuntimeFailure outcomes. snapshot(), validate(), disable(), reenable() require manifestValidation capability; evaluate() requires suppliedDocumentEvaluation capability.

#### Scenario: Disposed runtime rejects snapshot
- **WHEN** dispose() has been called on the runtime
- **THEN** snapshot() returns a disposed failure outcome

#### Scenario: Unavailable runtime rejects validate
- **WHEN** the runtime was constructed with OnlineRuleSourceRuntime.unavailable()
- **THEN** validate() returns an unavailable failure outcome

#### Scenario: Unsupported scope evaluate returns capabilityUnsupported
- **WHEN** the scope has suppliedDocumentEvaluation capability marked unsupported
- **THEN** evaluate() returns a capabilityUnsupported failure outcome

### Requirement: Online rule source runtime SHALL support disable and safe reenable
The system SHALL provide disable(scopeId) that sets stored manifest validationState to disabled, and reenable(scopeId) that restores only disabled-to-valid, rejecting invalid manifests. reenable() SHALL be idempotent if the manifest is already valid.

#### Scenario: Disable sets validation state to disabled
- **WHEN** disable() is called for a scope with a valid manifest
- **THEN** the stored manifest validationState becomes disabled

#### Scenario: Reenable restores disabled to valid
- **WHEN** reenable() is called for a scope with a disabled manifest
- **THEN** the stored manifest validationState becomes valid

#### Scenario: Reenable rejects invalid manifest
- **WHEN** reenable() is called for a scope with an invalid manifest
- **THEN** the runtime returns a manifestInvalid failure

#### Scenario: Reenable is idempotent for valid manifest
- **WHEN** reenable() is called for a scope with a valid manifest
- **THEN** the runtime returns success with the current state unchanged

### Requirement: Online rule source runtime MUST remain scoped to Step 27
The system MUST keep gateway page retrieval, network fetch, WebView challenge handling, captcha solving, DNS/network policy behavior, diagnostics center actions, Flutter rendering, yuc.wiki special-casing, libtorrent bindings, registerSource, and refreshManifest outside the online rule source runtime slice.

#### Scenario: Boundary checker rejects out-of-scope dependencies
- **WHEN** boundary checks scan Step 27 runtime, test, and checker files
- **THEN** no gateway, network client, WebView, captcha, DNS client, proxy server, diagnostics center, Flutter widget, libtorrent, registerSource, or refreshManifest dependency is found

### Requirement: Online rule source runtime SHALL use Step 48 evaluator behavior through existing projections
The online rule source runtime SHALL continue to expose validation,
evaluation, normalized output, and restart projections through
`OnlineRuleSourceRuntime` while the underlying evaluator performs concrete
supplied-document extraction.

#### Scenario: Source runtime evaluates a supplied document
- **WHEN** `OnlineRuleSourceRuntime.evaluate()` receives a manifest with
  supported Step 48 CSS, XPath, or regex operations
- **THEN** the resulting projection stores the evaluation snapshot and exposes
  the normalized output through existing typed projection fields

### Requirement: Online rule source runtime SHALL preserve Step 48 boundaries
The Step 48 source runtime integration SHALL NOT add gateway page retrieval,
network fetch, WebView challenge handling, captcha solving, DNS/proxy behavior,
diagnostics actions, Flutter UI, yuc.wiki special-casing, libtorrent bindings,
RSS auto-download, or concrete app-shell dependencies.

#### Scenario: Boundary checker scans Step 48 files
- **WHEN** Step 48 runtime, tests, tools, and docs are scanned
- **THEN** concrete UI, WebView, network fetch, captcha, BT, RSS auto-download,
  and source-specific scraper dependencies are absent

### Requirement: Online rule source runtime SHALL remain separate from the test harness
The online rule source runtime SHALL remain the storage-backed runtime
acceptance layer, while the Step 49 test harness remains a non-persistent
caller-supplied-document helper.

#### Scenario: Harness test run executes
- **WHEN** a rule-source test plan is run
- **THEN** it does not mutate `OnlineRuleRuntimeStore`, publish cache
  invalidation events, disable or reenable manifests, or replace
  `OnlineRuleSourceRuntime` projections

### Requirement: Online rule test harness SHALL preserve source runtime boundaries
The Step 49 harness SHALL NOT add gateway page retrieval, network fetch,
WebView challenge handling, captcha solving, DNS/proxy behavior, diagnostics
actions, Flutter UI, yuc.wiki special-casing, libtorrent bindings, RSS
auto-download, or app-shell dependencies.

#### Scenario: Boundary checker scans Step 49 files
- **WHEN** Step 49 runtime, tests, tools, and docs are scanned
- **THEN** concrete UI, WebView, network fetch, captcha, BT, RSS auto-download,
  diagnostics actions, and source-specific scraper dependencies are absent

