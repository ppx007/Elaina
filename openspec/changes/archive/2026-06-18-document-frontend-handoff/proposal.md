# document-frontend-handoff

## Why

The core/runtime work through Step 60 is ready for external UI implementation,
but the handoff knowledge is spread across phase notes, player integration
notes, smoke-gate docs, OpenSpec specs, and exported Dart contracts. The UI
model needs one stable entry document that states what is ready, what UI owns,
which contracts to consume, which boundaries are forbidden, and how to validate
integration.

## What Changes

- Add a frontend handoff document under `docs/`.
- Link the handoff document from `README.md`.
- Record the handoff document as part of the repository baseline.

## Non-Goals

- No Flutter UI, app shell, route, page, widget, file picker, video surface,
  native runner, or `lib/main.dart` implementation.
- No new runtime behavior, dependency, checker framework, or contract API.
- No claim that the app is final-user release-ready before UI/native smoke
  joins the core gates.

## Validation

- OpenSpec validation for the change.
- Documentation review for boundary clarity and current-state accuracy.
