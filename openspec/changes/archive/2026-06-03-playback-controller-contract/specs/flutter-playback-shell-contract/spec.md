## ADDED Requirements

### Requirement: Flutter playback shell SHALL support controller-driven mock playback
The Flutter playback shell SHALL be able to render and dispatch through a controller-backed shell driver that consumes playback page surface descriptors, playback page intents, and playback state snapshots while preserving UI-only ownership of Flutter widgets.

#### Scenario: Shell dispatches through controller-backed driver
- **WHEN** a visible shell control is activated with a controller-backed driver
- **THEN** the shell dispatches the corresponding playback page intent through the driver and renders the resulting controller-backed playback state without importing MPV, VLC, libmpv, media-kit, provider internals, streaming internals, gateway, storage, network, or native bindings
