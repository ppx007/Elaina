## ADDED Requirements

### Requirement: Video enhancement intent SHALL be mappable to concrete MPV plans
The video enhancement pipeline SHALL remain declarative while allowing a
Playback-owned concrete MPV binding to translate supported profile intent into
MPV option and command plans at the adapter boundary.

#### Scenario: Declarative profile crosses into Playback binding
- **WHEN** a selected enhancement profile reaches the concrete MPV binding
- **THEN** scaler, HDR tone mapping, deband, and Anime4K-style intent are mapped
  by Playback-owned code into MPV command data without changing UI-facing
  profile contracts or the deterministic enhancement runtime

#### Scenario: Unsupported shader intent lacks a concrete shader path
- **WHEN** Anime4K-style intent cannot be represented by the available concrete
  MPV command plan
- **THEN** the binding returns a typed unsupported or rejected enhancement
  result rather than claiming a shader bundle was applied
