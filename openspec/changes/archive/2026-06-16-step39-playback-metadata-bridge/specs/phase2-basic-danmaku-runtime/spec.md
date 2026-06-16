## ADDED Requirements

### Requirement: Basic danmaku runtime SHALL accept provider comments through a bridge
The basic danmaku runtime SHALL remain provider-client-neutral while allowing a
Domain playback metadata bridge to load normalized Dandanplay comments through
existing `DanmakuComment` conversion.

#### Scenario: Dandanplay comments are prepared for playback
- **WHEN** the metadata bridge receives Dandanplay comment provider results for
  an episode
- **THEN** it converts those comments to Playback-layer `DanmakuComment`
  values, loads `BasicDanmakuRuntime`, and resolves a clock-driven danmaku
  projection without importing concrete Dandanplay API clients into Playback
  rendering code
