## ADDED Requirements

### Requirement: Phase 1 player core runtime SHALL preserve layer isolation
The system SHALL provide an executable Phase 1 player core runtime bootstrap that composes only Playback and approved Domain-facing playback surfaces while preserving UI, Foundation, Provider, Gateway, Storage, Streaming, and Network isolation.

#### Scenario: Player core runtime is constructed
- **WHEN** the Phase 1 player core runtime bootstrap is created for tests or early app-shell wiring
- **THEN** it does not import Flutter UI, provider implementations, storage implementations, streaming engines, network clients, concrete MPV/libmpv/media-kit bindings, VLC, BT engines, online rule runtimes, or diagnostics UI

### Requirement: Layer boundary checks SHALL cover player core runtime wiring
The system SHALL include executable checks that reject forbidden cross-layer dependencies in Phase 1 player core runtime and bootstrap files.

#### Scenario: Player core runtime imports a forbidden system
- **WHEN** player core runtime introduces direct dependencies on Flutter widgets, concrete provider integrations, storage internals, BT streaming, network clients, VLC fallback, native player bindings, diagnostics UI, or online rule parsing
- **THEN** the boundary checker fails before the runtime can be treated as a valid Phase 1 implementation
