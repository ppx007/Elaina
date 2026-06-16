## ADDED Requirements

### Requirement: Subtitle provider runtime SHALL consume concrete providers unchanged
The subtitle-provider runtime SHALL consume concrete subtitle providers through
the existing `SubtitleProvider` contract without provider-specific branches,
new runtime abstractions, UI dependencies, storage implementation dependencies,
or concrete network policy ownership.

#### Scenario: OpenSubtitles provider is configured
- **WHEN** app composition supplies an OpenSubtitles-backed `SubtitleProvider`
  to `SubtitleProviderBootstrap`
- **THEN** search, retrieval, cache reuse, parser handoff, snapshots, and
  normalized failures flow through the existing runtime path
