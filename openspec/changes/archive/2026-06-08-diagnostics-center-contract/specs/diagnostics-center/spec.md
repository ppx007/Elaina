## ADDED Requirements

### Requirement: Diagnostics center SHALL expose capability status
The diagnostics center SHALL expose capability state for local event recording, schema registration, snapshot creation, query filtering, local export, retention enforcement, and redaction.

#### Scenario: Export capability unavailable
- **WHEN** local diagnostics export is unavailable on a platform or build
- **THEN** diagnostics reports the limitation through typed capability state rather than attempting remote telemetry, cloud upload, or fallback lifecycle actions

### Requirement: Diagnostics center SHALL thread correlation identity across extension flows
The diagnostics center SHALL preserve correlation identity across ProviderGateway failures, RSS automation evaluations, online rule evaluations, WebView session backfill attempts, network policy decisions, cache events, storage events, playback events, BT events, and A/V sync events.

#### Scenario: Provider request is blocked by network policy
- **WHEN** ProviderGateway reports a provider-scoped request blocked by network policy
- **THEN** diagnostics can record a local structured event with the provider failure classification, network policy failure kind, and shared correlation identity

### Requirement: Diagnostics center SHALL persist only redacted snapshots and exports
The diagnostics center SHALL apply redaction policy before persistence and export for sensitive session, authorization, cookie, token, filesystem, and provider-secret payload fields.

#### Scenario: Snapshot contains session-adjacent metadata
- **WHEN** a diagnostics snapshot includes WebView backfill artifact metadata or provider authorization context
- **THEN** the stored snapshot and local export omit or redact sensitive values while preserving safe identifiers and correlation metadata
