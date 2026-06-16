## ADDED Requirements

### Requirement: UI integration SHALL observe lifecycle and dispose runtime through Domain contracts
UI integration SHALL observe playback lifecycle state and dispose player-core
runtime objects through Domain-facing contracts, without importing concrete
media_kit/libmpv backend objects or relying on Flutter widget disposal as the
only runtime cleanup mechanism.

#### Scenario: Playback is opened from a prepared source
- **WHEN** the app integration layer opens a prepared playback source through
  `PlaybackControllerContract`
- **THEN** lifecycle state transitions are observable through
  `PlaybackStateObserver` and `currentState` without requiring UI code to
  inspect concrete backend state

#### Scenario: Player runtime is disposed
- **WHEN** the app integration owner disposes `PlayerCoreBootstrap` or
  `PlayerCoreRuntime`
- **THEN** later commands return normalized disposed failures or state errors
  through Domain contracts rather than leaking concrete backend exceptions
  into UI code

### Requirement: UI integration SHALL present normalized playback errors
UI integration SHALL treat playback command failures, source handoff failures,
and disposed-runtime outcomes as normalized contract results that can be
displayed or logged without parsing concrete backend exception text.

#### Scenario: Unsupported source is opened
- **WHEN** an unsupported source reaches the playback controller
- **THEN** the controller returns a normalized unsupported playback failure and
  publishes failed lifecycle state instead of delegating blindly to the
  concrete player backend
