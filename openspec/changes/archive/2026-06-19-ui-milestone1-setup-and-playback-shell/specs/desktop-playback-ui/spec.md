## ADDED Requirements

### Requirement: Playback UI SHALL render from contract surface descriptors
The playback page SHALL render video elements and controls purely based on the active `PlaybackPageSurfaceDescriptor` and the capability matrix, without referencing concrete playback adapters or native bindings.

#### Scenario: Render play/pause, seek, stop controls
- **WHEN** the active surface descriptor indicates seek, playPause, and stop are supported and visible
- **THEN** the playback page renders the play/pause button, the progress seek bar, and the stop button
- **AND** hides or disables controls for unsupported capabilities

### Requirement: Playback UI controls SHALL dispatch page intents
The playback page controls SHALL translate user actions into `PlaybackPageIntent` commands and dispatch them through the playback driver contract interface.

#### Scenario: User clicks play button
- **WHEN** the user activates the play button in the control overlay
- **THEN** the playback page dispatches the `PlaybackPageIntent.play()` intent and updates its UI based on the returned intent result and subsequent state updates

### Requirement: Playback UI SHALL open local files via handoff
The playback page SHALL provide a file picker UX that hands off selected file paths to the `LocalPlaybackSourceHandoff` converter to open them securely in the playback controller.

#### Scenario: Select local file via file picker
- **WHEN** the user selects a media file path using the native file picker in the UI
- **THEN** the UI passes the path to `LocalPlaybackSourceHandoff.prepare()`
- **AND** if the handoff result is successful, invokes `controller.open()` with the prepared source
- **AND** if the handoff fails, surfaces the typed error message to the user without crashing
