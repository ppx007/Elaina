## ADDED Requirements

### Requirement: Video enhancement pipeline contract SHALL persist enhancement profile state
The system SHALL define durable video enhancement profile contracts for built-in profiles, user-defined profiles, active profile selection, and latest pipeline state metadata without storing concrete shader graphs, renderer handles, native plugin state, or platform adapter internals.

#### Scenario: Enhancement profile survives restart
- **WHEN** a user selects or creates a video enhancement profile
- **THEN** later Playback flows can restore the declarative scaler, HDR, deband, and Anime4K-style intent through Storage contracts without loading MPV shader files, native plugins, or renderer-specific state

### Requirement: Video enhancement pipeline contract SHALL evaluate profiles against capabilities
The system SHALL evaluate video enhancement profiles against adapter and platform capability reports before applying them, returning typed supported or unsupported outcomes with explicit reason strings for rejected profile components.

#### Scenario: Adapter rejects Anime4K preset
- **WHEN** a selected profile requires an Anime4K-style preset but the active adapter capability report does not support Anime4K
- **THEN** evaluation returns an unsupported outcome with a reason and does not apply concrete renderer state

### Requirement: Video enhancement pipeline contract SHALL expose deterministic apply and disable outcomes
The system SHALL define typed outcomes for applying, disabling, and requesting degradation of video enhancement profiles without throwing concrete adapter exceptions or requiring native rendering implementations.

#### Scenario: Profile application is accepted
- **WHEN** a capability-supported enhancement profile is applied through the deterministic contract
- **THEN** the pipeline records an applied state and publishes an invalidation event without invoking MPV, VLC, FFI, shader compiler, or platform renderer code

### Requirement: Video enhancement pipeline contract SHALL expose render budget snapshots
The system SHALL expose render budget inputs and latest enhancement pressure snapshots that future AVSyncGuard work can consume without making the enhancement pipeline own drift policy or diagnostics center behavior.

#### Scenario: Enhancement exceeds budget
- **WHEN** estimated render cost exceeds the available frame budget for an active profile
- **THEN** the pipeline exposes budget pressure and a degradation target as contract data while leaving deterministic A/V sync policy selection to AVSyncGuard

### Requirement: Video enhancement pipeline contract SHALL publish enhancement invalidation events
The system SHALL publish cache invalidation events when enhancement profiles change, capabilities are reevaluated, or pipeline state transitions between disabled, evaluated, applied, rejected, or degraded states.

#### Scenario: Active enhancement profile changes
- **WHEN** the active enhancement profile changes for playback
- **THEN** an enhancement invalidation event is published so playback surfaces and future diagnostics consumers can refresh derived state without direct cross-module mutation

### Requirement: Video enhancement pipeline contract MUST remain scoped to Step 22
The system MUST keep concrete MPV shader graphs, Anime4K shader bundles, native renderer bindings, VLC fallback selection, AVSyncGuard policy implementation, diagnostics center behavior, DNS/network policy, online source rules, RSS automation, WebView challenge handling, and Flutter rendering outside the VideoEnhancementPipeline contract slice.

#### Scenario: Phase 5 checker runs
- **WHEN** boundary checks scan Step 22 contracts
- **THEN** no concrete shader implementation, native plugin, FFI, VLC fallback, diagnostics center, network policy, automation extension, or Flutter widget dependency is required by the video enhancement pipeline contract
