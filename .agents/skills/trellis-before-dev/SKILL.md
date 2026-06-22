---
name: trellis-before-dev
description: "Loads supplemental project-local conventions from .trellis/spec before implementation when they are relevant. OpenSpec remains the active workflow and behavior authority."
---

# Supplemental Trellis Spec Read

Use this skill only to refresh local coding conventions. It is not a gate that
blocks straightforward implementation, and it does not replace OpenSpec.

## Authority

- Follow `AGENTS.md`, `README.md`, OpenSpec, and the latest user request first.
- Use `.trellis/spec/` for implementation habits, testing heuristics, and
  historical gotchas.
- Ignore generic "to fill" Trellis template content.

## Steps

1. Discover available Trellis spec indexes:

   ```powershell
   python .\.trellis\scripts\get_context.py --mode packages
   ```

2. Pick only the indexes relevant to the files you are about to touch.

3. Read those indexes and any linked guideline files that contain concrete
   Elaina-specific rules.

4. Return to normal OpenSpec-first development and validate with the Dart CLI.

Do not create Trellis tasks or launch legacy Trellis agents from this skill.
