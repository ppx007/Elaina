---
description: OMO-style alias for starting an OpenSpec spec-driven change
---

Start an OMO-style spec-driven workflow using this project's installed OpenSpec
tooling.

This command is a local compatibility shim for community references to
`/omo-spec`. Upstream OMO does not currently ship a native `/omo-spec` command;
the installed OpenSpec integration provides the `opsx-*` commands and
`openspec-*` skills. Use those primitives here.

**Input**: The argument after `/omo-spec` is the feature, project, change name,
or problem statement to turn into an OpenSpec change.

**Behavior**

1. If no input was provided, ask the user what they want to build or fix.
2. Treat the input exactly like `/opsx-propose <input>`:
   - derive a kebab-case change name when the user gave a description
   - run `openspec new change "<name>"`
   - run `openspec status --change "<name>" --json`
   - create the required proposal/design/tasks artifacts in dependency order
   - re-check status until the change is ready for apply
3. After the proposal artifacts are ready, show the current status and tell the
   user the next command:
   - `/opsx-apply <name>` to implement
   - `/opsx-archive <name>` after implementation is complete

**Rules**

- Use the existing OpenSpec CLI and generated OpenSpec skills. Do not invent a
  separate `.omo/spec` workflow in this repository.
- Do not start implementation unless the user explicitly asks to implement or
  apply the change.
- Preserve this project's OpenSpec authority and architecture constraints from
  `openspec/config.yaml`.
