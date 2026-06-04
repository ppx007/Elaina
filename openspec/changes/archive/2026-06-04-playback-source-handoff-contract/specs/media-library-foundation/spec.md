## ADDED Requirements

### Requirement: Local media values SHALL be usable as playback handoff inputs
Local media identity and scan candidate contracts SHALL carry enough source information for a playback source handoff to prepare local file playback without requiring provider metadata, storage-backed library state, or network access.

#### Scenario: Scan candidate is selected for playback
- **WHEN** a user or test selects a media scan candidate with a file URI
- **THEN** the candidate can be passed to the playback source handoff without resolving Bangumi bindings, provider metadata, playback history, storage records, gateway requests, or network resources
