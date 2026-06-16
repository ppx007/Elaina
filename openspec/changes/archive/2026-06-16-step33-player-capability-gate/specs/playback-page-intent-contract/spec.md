## ADDED Requirements

### Requirement: Playback page intents SHALL remain capability-gated for local-file runtime
Playback page intents SHALL use the active surface descriptor as the execution
gate for local-file runtime actions, so unsupported controls cannot dispatch
controller commands just because a concrete player binding exists.

#### Scenario: Unsupported local-file surface action is dispatched
- **WHEN** a playback page intent targets a control or panel omitted from the
  local-file runtime surface descriptor
- **THEN** the intent returns an unsupported result without calling the
  corresponding Domain command
