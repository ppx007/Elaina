## ADDED Requirements

### Requirement: Local media scanner SHALL refine the existing MediaLibraryScanner contract
The local media scanner contract SHALL define local file scanning behavior through the existing `MediaLibraryScanner`, `MediaScanScope`, `MediaScanResult`, `MediaScanFailure`, and `MediaScanEvent` contracts rather than introducing a parallel scanner API.

#### Scenario: Scanner contract is implemented
- **WHEN** a local media scanner is added for contract validation
- **THEN** it implements the existing `MediaLibraryScanner` surface and returns existing Domain media values rather than scanner-local, UI-local, storage-local, playback-local, or provider-local media models

### Requirement: Local media scanner SHALL normalize supported scan scopes
The local media scanner contract SHALL define deterministic scan-scope normalization for file URI roots, extension filters, recursion, and exclude patterns before any concrete filesystem traversal is added.

#### Scenario: Supported scan scope is normalized
- **WHEN** a scan scope contains file URI roots, extension filters, recursion settings, and exclude patterns
- **THEN** the scanner evaluates those values through normalized Domain media rules without depending on platform path APIs, UI state, storage-backed library state, provider metadata, gateway traffic, network clients, streaming engines, or native player bindings

### Requirement: Local media scanner SHALL produce handoff-safe media scan candidates
The local media scanner contract SHALL produce `MediaScanCandidate` values whose `LocalMediaIdentity` has a non-empty file URI, non-empty basename, and non-negative size.

#### Scenario: Local file scope discovers a candidate
- **WHEN** a scanner evaluates a supported local file scan scope and discovers a playable entry
- **THEN** the entry is represented as a `MediaScanCandidate` that can be validated without provider metadata, storage-backed library state, gateway traffic, network clients, streaming engines, UI widgets, or native player bindings

### Requirement: Local media scanner SHALL publish scan progress through Domain media events
The local media scanner contract SHALL expose discovered candidates, progress updates, completion, and failure information through existing `MediaScanEvent` and `MediaScanResult` values.

#### Scenario: Candidate discovery is observed
- **WHEN** a local scan discovers a candidate before completion
- **THEN** observers receive a Domain media scan event carrying the candidate rather than a concrete filesystem, UI, storage, provider, network, streaming, playback, or native-player callback

### Requirement: Local media scanner SHALL normalize unsupported scopes and scan failures
The local media scanner contract SHALL return typed scan failure information for unsupported roots, unsupported URI schemes, excluded entries, unreadable entries, cancelled scans, or candidate discovery failures.

#### Scenario: Unsupported scan root is evaluated
- **WHEN** a scan scope includes a root that cannot be represented as a supported local file scan input
- **THEN** the scanner reports a normalized typed scan failure instead of throwing a concrete platform, provider, storage, gateway, network, streaming, UI, playback, or native-player exception

### Requirement: Local media scanner SHALL define cancellation and watch semantics
The local media scanner contract SHALL define cancellation as idempotent and SHALL specify the watch stream behavior for active, completed, failed, unknown, and cancelled scan ids.

#### Scenario: In-progress scan is cancelled
- **WHEN** a caller cancels an active local media scan by scan id
- **THEN** the scanner stops publishing new discovery or progress events for that scan id and exposes a deterministic terminal outcome through Domain media contracts

### Requirement: Local media scanner MUST preserve layer isolation
The local media scanner contract MUST NOT require Provider, Gateway, Storage implementation, Streaming, Network, Flutter UI, MPV, VLC, libmpv, media-kit, platform channel, diagnostics, danmaku, Anime4K, RSS, Bangumi, Dandanplay, BT, or online rule runtime dependencies.

#### Scenario: Scanner imports are checked
- **WHEN** automation scans local media scanner contracts and runtime checks
- **THEN** no dependency on provider implementations, gateway implementations, storage implementations, streaming implementations, network implementations, UI widgets, native player bindings, or later-phase ACG integrations is required
