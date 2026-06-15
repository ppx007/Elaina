## MODIFIED Requirements

### Requirement: VLC fallback adapter contract SHALL expose typed fallback outcomes
The system SHALL return typed registration, evaluation, selection, disable, and capability-reevaluation outcomes for fallback actions instead of relying on nullable selection semantics or concrete adapter exceptions. The runtime acceptance layer SHALL surface these outcomes through `FallbackAdapterRuntimeActionResult<T>` with success/failed/unavailable/disposed variants.

#### Scenario: No fallback candidate is available
- **WHEN** a fallback-compatible primary adapter failure occurs but no registered candidate can support the source
- **THEN** the outcome contains a typed no-candidate failure with an explicit reason and no mandatory VLC dependency is assumed

#### Scenario: Runtime surfaces contract failures through typed ActionResult
- **WHEN** the runtime wraps a strategy method that returns a contract failure
- **THEN** the runtime returns a `FallbackAdapterRuntimeActionResult` with kind `failed` and a `FallbackAdapterRuntimeFailure` mapping the contract failure kind to the runtime failure kind

## ADDED Requirements

### Requirement: VLC fallback adapter contract SHALL enforce runtime boundary
The system SHALL ensure that the fallback adapter runtime acceptance layer does not import or depend on concrete VLC implementations, PlayerAdapter method invocations, native plugins, FFI, Flutter widgets, diagnostics center, RSS automation, online rule runtime, WebView, captions, or network policy.

#### Scenario: Runtime boundary scan
- **WHEN** boundary checks scan the fallback adapter runtime file
- **THEN** no PlayerAdapter import, VLC binding, or cross-domain dependency is present in the runtime slice
