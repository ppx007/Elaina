## ADDED Requirements

### Requirement: VLC fallback adapter contract SHALL persist declarative fallback state
The system SHALL define durable fallback adapter records for candidate registration, active fallback configuration, selection history, and latest fallback strategy state without storing native adapter handles, VLC objects, platform resources, or concrete player instances.

#### Scenario: Fallback state is restored
- **WHEN** fallback adapter candidates and active fallback configuration are written to Storage
- **THEN** later playback preparation can restore fallback intent and selection history without depending on a concrete VLC implementation

### Requirement: VLC fallback adapter contract SHALL evaluate fallback deterministically
The system SHALL define deterministic fallback evaluation using normalized playback failure data, playback source type, candidate priority, candidate capability matrices, fallback enablement state, and hidden capability reasons.

#### Scenario: Compatible fallback candidate exists
- **WHEN** the primary adapter reports a fallback-compatible load failure for a source supported by a registered fallback candidate
- **THEN** the strategy returns a typed selection outcome that identifies the candidate and hidden capabilities before any concrete adapter is invoked

### Requirement: VLC fallback adapter contract SHALL expose typed fallback outcomes
The system SHALL return typed registration, evaluation, selection, disable, and capability-reevaluation outcomes for fallback actions instead of relying on nullable selection semantics or concrete adapter exceptions.

#### Scenario: No fallback candidate is available
- **WHEN** a fallback-compatible primary adapter failure occurs but no registered candidate can support the source
- **THEN** the outcome contains a typed no-candidate failure with an explicit reason and no mandatory VLC dependency is assumed

### Requirement: VLC fallback adapter contract SHALL hide unsupported fallback capabilities
The system SHALL preserve capability differences after fallback by exposing hidden capabilities and reason strings for features the selected fallback adapter cannot support.

#### Scenario: Fallback lacks advanced rendering
- **WHEN** a fallback adapter is selected and lacks advanced rendering, caption, or danmaku capabilities
- **THEN** the fallback selection carries unsupported capability statuses so UI can hide or disable those features through the capability matrix

### Requirement: VLC fallback adapter contract MUST remain optional and adapter-neutral
The system MUST keep concrete VLC packages, native plugins, FFI, media-kit/libmpv bridges, platform player implementations, Flutter widgets, diagnostics center integration, RSS automation, online rule runtime, WebView handling, DNS policy, and network policy outside the fallback adapter contract slice.

#### Scenario: Phase 5 checker runs
- **WHEN** boundary checks scan Step 25 contracts
- **THEN** no concrete VLC binding, native fallback implementation, UI widget, diagnostics center, or Phase 6 provider/network dependency is required by the fallback contract
