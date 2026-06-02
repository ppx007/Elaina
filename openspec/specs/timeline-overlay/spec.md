# timeline-overlay Specification

## Purpose
TBD - created by archiving change bootstrap-bt-streaming-core. Update Purpose after archive.
## Requirements
### Requirement: Timeline overlay SHALL expose playback and buffer read models
The system SHALL define timeline overlay contracts for playback progress, buffered ranges, and BT piece states without giving UI direct control over download tasks.

#### Scenario: Timeline is rendered
- **WHEN** UI renders a playback timeline
- **THEN** it consumes overlay read models rather than concrete BT task or download engine objects

### Requirement: Timeline overlay SHALL support layered markers
The system SHALL define marker or heat layers that can represent buffer, piece, danmaku, subtitle, or future diagnostic hints as separate overlay layers.

#### Scenario: Multiple timeline layers are available
- **WHEN** playback, buffer, and marker data are available
- **THEN** the timeline overlay exposes them as distinct layers that UI can show or hide

### Requirement: Timeline overlay MUST remain presentation-facing
The system MUST keep timeline overlay contracts as read models and avoid making them responsible for BT task lifecycle, RSS auto-download, or diagnostics-center behavior.

#### Scenario: User inspects piece progress
- **WHEN** UI displays piece progress on the timeline
- **THEN** it reads overlay data and does not mutate BT task or scheduler state through the overlay

