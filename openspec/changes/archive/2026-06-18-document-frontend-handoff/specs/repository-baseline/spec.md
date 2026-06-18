## ADDED Requirements

### Requirement: Repository baseline SHALL provide a frontend handoff entry point
The repository baseline SHALL provide a documented handoff entry point for
external frontend implementation that summarizes current core readiness,
UI-owned work, allowed contracts, forbidden implementation dependencies,
validation commands, and release-readiness gaps without changing runtime code.

#### Scenario: Frontend model starts implementation
- **WHEN** an external frontend model joins the project
- **THEN** it can read the handoff document to identify the app-shell,
  routing, page, file-picker, video-surface, and manual UI smoke work it owns
  and the Domain/Playback/runtime contracts it should consume
