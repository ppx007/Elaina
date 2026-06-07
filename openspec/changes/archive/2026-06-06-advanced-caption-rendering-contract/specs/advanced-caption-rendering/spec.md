## ADDED Requirements

### Requirement: Advanced caption rendering SHALL use durable feature state
The system SHALL back Matrix4 danmaku, dual subtitles, PGS subtitle rendering, and ASS subtitle enhancement with durable feature state and typed evaluation outcomes.

#### Scenario: Advanced caption feature is evaluated
- **WHEN** an advanced caption render request is created
- **THEN** the renderer contract evaluates active feature state and capability status before exposing the request as executable

### Requirement: Advanced caption rendering SHALL separate advanced requests from basic foundations
The system SHALL represent Matrix4 danmaku transforms, ordered dual subtitles, PGS rendering intent, and ASS enhancement intent as advanced rendering requests without mutating basic subtitle parser or danmaku event contracts.

#### Scenario: ASS enhancement request is prepared
- **WHEN** ASS enhancement rendering is requested
- **THEN** the request is represented as an advanced rendering intent while basic ASS parser output remains unchanged
