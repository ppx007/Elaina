## ADDED Requirements

### Requirement: Runtime SHALL publish advanced caption invalidation events on evaluation and rendering
The system SHALL ensure cache invalidation bus receives `AdvancedCaptionCapabilityReevaluated`, `AdvancedCaptionRendererStateChanged`, and `AdvancedCaptionProfileChanged` events when the runtime delegates evaluate, render, or disable operations to the deterministic renderer.

#### Scenario: Evaluate publishes capability and state events
- **WHEN** the runtime evaluates an advanced caption profile on a supported scope
- **THEN** `AdvancedCaptionCapabilityReevaluated` and `AdvancedCaptionRendererStateChanged` events are published after store visibility is established

### Requirement: Runtime SHALL publish dual subtitle selection invalidation
The system SHALL ensure `AdvancedCaptionDualSubtitleSelectionChanged` is published when the runtime delegates dual subtitle rendering on a supported scope.

#### Scenario: Dual subtitle render publishes selection event
- **WHEN** the runtime renders dual subtitles on a supported scope
- **THEN** `AdvancedCaptionDualSubtitleSelectionChanged` event is published after the store records the selection

### Requirement: Runtime SHALL publish degradation state invalidation
The system SHALL ensure `AdvancedCaptionDegradationStateChanged` is published when the runtime accepts an AV sync degradation decision on a supported scope.

#### Scenario: Degradation acceptance publishes state event
- **WHEN** the runtime accepts a `disableAdvancedCaptions` degradation action on a supported scope
- **THEN** `AdvancedCaptionDegradationStateChanged` event is published after the store records the degraded state
