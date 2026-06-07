# advanced-caption-rendering-contract Specification

## Purpose
TBD - created by archiving change advanced-caption-rendering-contract. Update Purpose after archive.
## Requirements
### Requirement: Advanced caption rendering contract SHALL persist declarative preferences
The system SHALL define durable advanced caption records for feature toggles, active feature selection, dual-subtitle ordering, and latest renderer state metadata without storing rendered frames, glyph atlases, image buffers, shader state, or native renderer handles.

#### Scenario: Advanced caption preferences are restored
- **WHEN** advanced caption preferences are written to Storage
- **THEN** later playback preparation can restore feature toggles and dual-subtitle ordering without depending on a concrete renderer implementation

### Requirement: Advanced caption rendering contract SHALL evaluate features deterministically
The system SHALL define deterministic feature evaluation for Matrix4 danmaku, dual subtitles, PGS subtitle rendering, and ASS subtitle enhancement using feature flags, capability reports, and request data.

#### Scenario: Feature is disabled by profile
- **WHEN** a render request targets an advanced caption feature disabled by the active profile
- **THEN** the evaluation outcome rejects the request with a typed failure and reason before the feature appears executable

### Requirement: Advanced caption rendering contract SHALL expose typed rendering outcomes
The system SHALL return typed render, disable, and degradation outcomes for advanced caption actions instead of relying on native-renderer exceptions or `void` success semantics.

#### Scenario: Unsupported PGS rendering is requested
- **WHEN** a PGS subtitle render request is evaluated on a platform that reports PGS rendering as unsupported
- **THEN** the outcome contains an unsupported feature failure with the capability reason and no concrete decoder is invoked

### Requirement: Advanced caption rendering contract SHALL preserve dual-subtitle order
The system SHALL preserve primary and secondary subtitle order in advanced caption state and render requests.

#### Scenario: Two subtitle tracks are selected
- **WHEN** primary and secondary subtitle tracks are saved for a playback scope
- **THEN** advanced caption rendering receives an ordered dual-subtitle request with the primary track before the secondary track

### Requirement: Advanced caption rendering contract SHALL accept AV sync degradation declaratively
The system SHALL expose a typed path for accepting `disableAdvancedCaptions` degradation decisions from AVSyncGuard without letting AVSyncGuard directly mutate renderer state.

#### Scenario: AV sync disables advanced captions
- **WHEN** AVSyncGuard emits a `disableAdvancedCaptions` degradation decision
- **THEN** advanced caption state records the degradation outcome and publishes invalidation without invoking a concrete caption renderer

### Requirement: Advanced caption rendering contract MUST remain scoped to Step 24
The system MUST keep concrete Flutter widgets, GPU rendering, Matrix4 layout engines, PGS decoders, ASS layout engines, native plugins, FFI, VLC fallback behavior, diagnostics center integration, RSS automation, online rule runtime, WebView handling, and network policy outside the advanced caption rendering contract slice.

#### Scenario: Phase 5 checker runs
- **WHEN** boundary checks scan Step 24 contracts
- **THEN** no concrete renderer, decoder, native plugin, FFI, VLC fallback, diagnostics center, Flutter widget, or Phase 6 provider/network dependency is required by the advanced caption rendering contract

