# layered-architecture Specification

## Purpose
TBD - created by archiving change bootstrap-phase-0-foundation. Update Purpose after archive.
## Requirements
### Requirement: Eight-layer boundaries SHALL be explicit
The system SHALL define UI, Domain, Playback, Provider, Gateway, Storage, Streaming, and Network as distinct architectural layers with named responsibilities and explicit interfaces between layers.

#### Scenario: New project structure is initialized
- **WHEN** the first implementation slice scaffolds the project structure
- **THEN** each of the eight layers is represented as a distinct module or package boundary with documented responsibility

### Requirement: Cross-layer direct dependencies MUST be restricted
The system MUST prevent upper-layer features from directly depending on concrete implementations that belong behind layer boundaries, including direct UI dependencies on player engines, provider integrations, streaming engines, source-specific feeds, and storage internals.

#### Scenario: UI feature requests playback or provider data
- **WHEN** a UI-facing feature needs playback, metadata, or provider behavior
- **THEN** it depends on Domain or other approved abstractions rather than directly importing concrete MPV, VLC, Bangumi, Dandanplay, libtorrent, yuc.wiki, or storage implementations

### Requirement: Extension points SHALL be preserved at layer seams
The system SHALL preserve extension points for Adapter, Provider, Profile, and FeatureFlag-driven substitution at the boundaries named by the architecture plan.

#### Scenario: A future engine or provider is introduced
- **WHEN** a new player adapter or external provider is added in a later phase
- **THEN** the new implementation plugs into an existing extension seam without forcing cross-layer redesign

### Requirement: Phase 0 foundation runtime SHALL preserve layer isolation
The system SHALL provide an executable Phase 0 foundation runtime bootstrap that composes only the Step 1-4 foundation layers while preserving UI, Domain, Playback, Provider, Gateway, Storage, Streaming, and Network isolation.

#### Scenario: Foundation runtime is constructed
- **WHEN** the Phase 0 foundation runtime bootstrap is created for tests or early app-shell wiring
- **THEN** it exposes only foundation-safe Gateway, Storage, cache invalidation, and layer manifest surfaces without importing Flutter UI, playback adapters, provider implementations, streaming engines, or concrete network adapters

### Requirement: Layer boundary checks SHALL cover foundation bootstrap wiring
The system SHALL include executable checks that reject forbidden cross-layer dependencies in the Phase 0 foundation runtime bootstrap.

#### Scenario: Bootstrap imports a forbidden concrete adapter
- **WHEN** the foundation runtime bootstrap introduces direct dependencies on MPV, VLC, libtorrent, Flutter UI, concrete HTTP clients, DNS/proxy clients, WebView controllers, or source-specific scrapers
- **THEN** the boundary checker fails before the bootstrap can be treated as a valid foundation implementation

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

