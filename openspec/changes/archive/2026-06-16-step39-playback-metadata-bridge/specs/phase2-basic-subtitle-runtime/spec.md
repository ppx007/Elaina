## ADDED Requirements

### Requirement: Basic subtitle runtime SHALL accept provider handoff through a bridge
The basic subtitle runtime SHALL remain provider-neutral while allowing a
Domain playback metadata bridge to load `SubtitleParseRequest` values prepared
by the subtitle-provider runtime.

#### Scenario: Provider subtitle is prepared for playback
- **WHEN** the metadata bridge receives a successful provider subtitle handoff
- **THEN** it loads the handoff parser request into `BasicSubtitleRuntime` and
  exposes the resulting subtitle projection without importing concrete
  OpenSubtitles clients or ProviderGateway internals into Playback subtitle code
