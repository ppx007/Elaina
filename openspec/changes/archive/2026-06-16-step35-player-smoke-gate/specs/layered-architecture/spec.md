## ADDED Requirements

### Requirement: Step 35 smoke gate SHALL remain outside UI implementation ownership
Step 35 smoke gate work SHALL provide non-UI playback and packaged release
verification tooling while leaving Flutter app shell, routes, pages, widgets,
file picker UX, video surfaces, and Windows runner implementation to the
external UI track.

#### Scenario: Smoke gate tooling is added
- **WHEN** Step 35 smoke gate tooling and docs are added
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  and validation continues to enforce concrete player dependency boundaries
