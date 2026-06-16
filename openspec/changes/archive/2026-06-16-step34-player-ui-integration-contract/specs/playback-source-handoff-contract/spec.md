## ADDED Requirements

### Requirement: UI integration SHALL prepare playback sources through handoff contracts
UI integration SHALL prepare playback sources through Domain/Playback handoff
contracts rather than passing platform file handles, media_kit objects,
provider records, storage records, or streaming snapshots directly into player
runtime commands.

#### Scenario: Local file is selected by UI-owned file picker
- **WHEN** UI-owned file picker code selects a local media URI
- **THEN** the app integration layer prepares a normalized
  `LocalFilePlaybackSource` through `PlaybackSourceHandoffContract` or an
  equivalent Domain-facing source contract before calling the playback
  controller

#### Scenario: Future virtual stream is selected
- **WHEN** BT streaming later produces a playback-owned virtual stream
  descriptor
- **THEN** the app integration layer maps it to a
  `VirtualStreamPlaybackSource` through playback-owned contracts before
  handing it to player runtime
