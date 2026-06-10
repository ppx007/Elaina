## ADDED Requirements

### Requirement: Local media scanner SHALL be consumable by media-library runtime
The local media scanner contract SHALL be directly consumable by the Step 14 media-library runtime through existing `MediaLibraryScanner`, `MediaScanScope`, `MediaScanResult`, `MediaScanFailure`, and `MediaScanEvent` contracts.

#### Scenario: Runtime executes deterministic scan
- **WHEN** the media-library runtime scans a supported file URI scope
- **THEN** it receives accepted candidates, typed failures, and scan events through existing Domain media contracts without platform filesystem traversal, storage implementation, provider metadata, UI widgets, network clients, streaming engines, or native-player bindings

### Requirement: Local media scanner runtime consumption SHALL preserve cancellation semantics
The scanner contract SHALL preserve deterministic cancellation and watch behavior when invoked through the media-library runtime.

#### Scenario: Runtime cancels scan
- **WHEN** the runtime cancels a scan id before or during scan resolution
- **THEN** subsequent scan or watch results expose a deterministic cancellation outcome through `MediaScanCancelled` or typed scan failure values without throwing concrete platform, storage, provider, UI, network, or playback exceptions

### Requirement: Local media scanner candidates SHALL remain handoff-safe after runtime scan
Media scan candidates returned through the media-library runtime SHALL retain handoff-safe `LocalMediaIdentity` values with source URI, basename, optional fingerprint, and non-negative size.

#### Scenario: Candidate is passed to playback handoff
- **WHEN** a runtime scan returns a local file candidate and the caller selects it for playback
- **THEN** the candidate can be passed to `PlaybackSourceHandoffContract` without provider metadata, catalog persistence, storage implementation, network resources, UI state, streaming engines, or native-player bindings

### Requirement: Local media scanner runtime checks MUST reject later-phase dependencies
Validation for the Step 14 scanner/runtime slice MUST reject subtitle provider, RSS, seasonal, BT, online-rule, diagnostics, concrete Flutter UI, ProviderGateway internals, storage implementation, network, MPV/VLC, and native-player dependencies.

#### Scenario: Scanner runtime boundary is checked
- **WHEN** automation scans media-library runtime and checker files
- **THEN** forbidden later-phase and concrete implementation dependencies are rejected while Domain media contracts remain allowed
