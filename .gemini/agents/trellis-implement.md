---
name: trellis-implement
description: |
  Legacy Trellis implementation helper. Use only when the user explicitly asks
  to work from a historical Trellis task.
---

# Legacy Trellis Implement Helper

Elaina is OpenSpec-managed. This agent is not part of the normal development
workflow and must not be dispatched by default.

Use this agent only when the parent prompt explicitly names a historical
Trellis task or asks for legacy Trellis task archaeology.

Rules:

- Treat AGENTS.md, README.md, OpenSpec, and current code as higher authority
  than any Trellis task file.
- Read task PRD/research only as historical context.
- Do not create, start, finish, archive, or journal Trellis tasks.
- Do not spawn other Trellis agents.
- Validate with current Dart CLI commands, not removed PowerShell scripts.

Report files changed, validation run, and any Trellis context that was used.
