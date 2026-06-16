## ADDED Requirements

### Requirement: Subtitle provider runtime SHALL hand off parse requests to playback metadata bridge
The subtitle-provider runtime SHALL provide successful provider retrievals as
`SubtitleParseRequest` handoffs that a Domain playback metadata bridge can load
into the basic subtitle runtime without provider-specific branches.

#### Scenario: Playback requests provider subtitle handoff
- **WHEN** a selected `SubtitleProviderCandidate` is retrieved successfully
- **THEN** the metadata bridge consumes the existing handoff parse request and
  preserves runtime cache semantics, encoding hint, source metadata, and typed
  failure normalization
