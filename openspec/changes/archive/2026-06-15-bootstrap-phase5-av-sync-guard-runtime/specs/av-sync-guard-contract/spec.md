## MODIFIED Requirements

### Requirement: AV sync guard contract SHALL expose typed evaluation and degradation outcomes
The system SHALL define typed outcomes for sample evaluation, health transitions, and degradation requests without throwing concrete adapter exceptions or requiring native rendering implementations. The runtime acceptance layer SHALL expose `AVSyncGuardRuntimeActionResult<T>` with success/failed/unavailable/disposed states so consuming code can inspect runtime-level outcomes without depending on guard internals.

#### Scenario: Runtime action result distinguishes success from failure
- **WHEN** the runtime processes an ingest or degradation request
- **THEN** the returned `AVSyncGuardRuntimeActionResult<T>` exposes `isSuccess` and typed failure kinds (unsupported, unavailable, disposed, policyNotConfigured, insufficientSamples)

## MODIFIED Requirements

### Requirement: AV sync guard contract MUST remain scoped to Step 23
The system MUST keep concrete MPV timing probes, libmpv/media-kit bindings, native renderer callbacks, VLC fallback selection, diagnostics center behavior, DNS/network policy, online source rules, RSS automation, WebView challenge handling, and Flutter rendering outside the AVSyncGuard contract slice. The runtime acceptance layer SHALL enforce this boundary by rejecting any import or dependency on native/UI/renderer/diagnostics/network/automation modules.

#### Scenario: Step 23 runtime boundary is enforced
- **WHEN** the runtime, tests, and checkers are scanned for boundary violations
- **THEN** no MPV property, native FFI, shader compiler, VLC adapter, diagnostics center, network policy, or Flutter widget dependency is found
