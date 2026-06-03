# playback-page-intent-contract Specification

## Purpose
TBD - created by archiving change implement-playback-page-intent-contract. Update Purpose after archive.
## Requirements
### Requirement: Playback page intent contract SHALL be UI-owned
The playback page intent contract SHALL live in the UI layer and SHALL depend only on UI playback surface descriptors and Domain-facing playback contracts, not concrete Playback, native-player, provider, streaming, gateway, storage, or network implementations.

#### Scenario: Intent contract dispatches through Domain
- **WHEN** the playback page intent contract resolves a user playback action
- **THEN** it dispatches through `PlaybackController` or equivalent Domain-facing playback commands without importing MPV, VLC, libmpv, media-kit, provider internals, streaming internals, or native player bindings

### Requirement: Playback page intents SHALL be framework-neutral
The playback page intent contract SHALL expose plain Dart intent and result types rather than Flutter widgets, BuildContext values, gestures, routes, themes, layout state, or native rendering handles.

#### Scenario: Future widgets bind to intents
- **WHEN** a future Flutter playback page binds a visible control to an action
- **THEN** it can create or dispatch a plain Dart intent without changing Domain or Playback contracts

### Requirement: Unsupported controls MUST NOT dispatch executable intents
The playback page intent contract MUST check the active playback page surface descriptor before dispatching executable transport, seek, panel, or track-selection intents.

#### Scenario: Seek control is unsupported
- **WHEN** the active playback page surface descriptor does not expose an active seek control
- **THEN** a seek intent returns an unsupported or ignored intent result without calling the Domain seek command

#### Scenario: Tracks panel is unsupported
- **WHEN** the active playback page surface descriptor does not expose an active tracks panel
- **THEN** an open-tracks-panel intent returns an unsupported or ignored intent result without activating a secondary panel

### Requirement: Playback page intent results SHALL be deterministic
The playback page intent contract SHALL return explicit result values for executed, ignored, and unsupported user actions.

#### Scenario: Intent is executable
- **WHEN** an intent is supported by the active playback page surface descriptor and the Domain command completes
- **THEN** the intent result reports the action as executed and preserves the Domain command outcome when one exists

#### Scenario: Intent is unsupported
- **WHEN** an intent is not supported by the active playback page surface descriptor
- **THEN** the intent result reports the action as unsupported or ignored without throwing for normal capability absence

### Requirement: Track selection intents SHALL use Domain track identifiers
The playback page intent contract SHALL use Domain-facing track identifiers for audio and subtitle track selection rather than UI-local, provider-local, or native-player track identifiers.

#### Scenario: Track selection is requested
- **WHEN** a playback page track-selection intent is dispatched
- **THEN** it passes a Domain-facing track identifier to the playback controller track-switching command

### Requirement: Later-phase systems MUST remain outside the intent contract
The playback page intent contract MUST NOT require provider metadata, danmaku rendering, advanced subtitle rendering, BT streaming, video enhancement, online rule parsing, VLC fallback, diagnostics integration, or native playback bindings.

#### Scenario: Intent contract is validated
- **WHEN** the playback page intent contract is checked by automation
- **THEN** validation completes without importing or requiring Bangumi, Dandanplay, RSS, BT streaming, Anime4K, VLC fallback, online rule runtime, diagnostics center, MPV, libmpv, or media-kit code

