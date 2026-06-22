---
name: trellis-start
description: "Refreshes optional Trellis context in this OpenSpec-managed project. Use only when legacy Trellis specs, tasks, or workspace notes may help; do not use it as the primary workflow entry."
---

# Trellis Context Refresh

Elaina is OpenSpec-managed. This skill does not start a Trellis workflow and
does not create a Trellis task. It only helps you inspect supplemental Trellis
context when that context is relevant.

## Authority Order

1. Current user instruction.
2. `AGENTS.md` and `README.md`.
3. Active OpenSpec specs and changes.
4. Current repository code.
5. `.trellis/spec/` supplemental conventions.
6. `.trellis/tasks/` and `.trellis/workspace/` historical material.

If Trellis conflicts with OpenSpec or project code, OpenSpec and the code win.

## Useful Reads

```powershell
python .\.trellis\scripts\get_context.py --mode packages
```

Read only the `.trellis/spec/**/index.md` files that are relevant to the files
you are touching. Do not load historical task PRDs or journals unless the user
explicitly asks for archaeology or they clearly explain the current bug.

## Normal Work

For implementation, continue in the main session:

```powershell
dart analyze
dart run tools\elaina_tool.dart check changed --scope Fast
openspec.cmd validate --all
```

Do not create Trellis tasks, launch legacy Trellis agents, archive Trellis tasks, or
write Trellis journals unless the user explicitly requests that legacy flow.
