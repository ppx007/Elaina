## ADDED Requirements

### Requirement: Fallback adapter SHALL use typed selection contracts
The system SHALL represent fallback registration, evaluation, selection, disablement, and rejection through typed outcomes and failures rather than nullable fallback selections.

#### Scenario: Fallback is rejected
- **WHEN** a primary adapter failure is not compatible with fallback or no candidate supports the requested source
- **THEN** the fallback strategy returns a typed failure with a reason instead of returning `null` without explanation

### Requirement: Fallback adapter SHALL preserve optional secondary adapter behavior
The system SHALL allow playback to surface the original normalized failure when no fallback adapter is enabled, registered, or compatible.

#### Scenario: Fallback is disabled
- **WHEN** fallback selection is disabled for the current playback scope
- **THEN** the fallback strategy reports a disabled fallback outcome and core playback does not require VLC availability

### Requirement: Fallback adapter SHALL report hidden capability differences
The system SHALL include unsupported fallback capabilities and reason strings in fallback selection results whenever a secondary adapter cannot provide features exposed by the primary adapter.

#### Scenario: Selected fallback hides capabilities
- **WHEN** a fallback candidate is selected with fewer capabilities than the primary adapter
- **THEN** the selection reports hidden capabilities so UI and Domain surfaces can remain capability-driven
