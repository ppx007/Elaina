## Why

Step 31-33 made concrete local playback available through a composition
contract and capability gate. The external UI track still needs a stable
integration contract describing how to open playback sources, observe lifecycle
state, dispose runtime objects, and present normalized errors without importing
concrete player backends or implementing UI in this change.

## What Changes

- Document the UI/app-shell integration flow for source handoff, runtime
  lifecycle, disposal, and error handling.
- Add focused regression coverage for the non-UI integration path:
  source handoff -> runtime open/play/failure state -> dispose behavior.
- Extend player-core checks so the integration notes and lifecycle/error
  contract remain present.
- Keep all UI implementation work outside this change.

## Impact

- Affected files are limited to docs, tests, checker scripts, and OpenSpec
  specs.
- This change MUST NOT modify `lib/src/ui/**`, `lib/main.dart`, or
  `windows/**`.
- The external UI model remains responsible for Flutter app shell, page,
  route, file picker, video surface, and visual state composition.
