## MODIFIED Requirements

### Requirement: Capability Matrix SHALL support future adapter expansion
The system SHALL allow future VLC, ExoPlayer, AVPlayer, advanced rendering, caption, and fallback adapters to add capability rows without rewriting playback UI contracts.

#### Scenario: A future fallback adapter is added
- **WHEN** a later change adds another player adapter
- **THEN** the adapter declares capabilities through the matrix instead of adding adapter-specific UI branches

#### Scenario: Advanced playback capability is unavailable
- **WHEN** advanced rendering, caption rendering, or fallback behavior is unavailable for the active adapter or platform
- **THEN** the capability matrix reports it as unsupported so UI hides or disables the feature
