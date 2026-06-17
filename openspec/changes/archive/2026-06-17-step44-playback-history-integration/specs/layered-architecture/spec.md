## ADDED Requirements

### Requirement: Playback history integration SHALL preserve UI and concrete-player boundaries
Playback history integration SHALL live in Domain media/runtime composition and
consume Domain playback state contracts without depending on Flutter UI or
concrete native player bindings.

#### Scenario: History integration is validated
- **WHEN** boundary checkers scan Step 44 implementation files
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  media_kit/libmpv/VLC imports stay out of Domain media files, and SQLite/SQL
  details remain behind storage adapters rather than leaking into playback
  history integration logic
