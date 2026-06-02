## Context

The latest archive left OpenSpec in a clean state with no active changes and 30 synced specs. The current workspace contains `.git/`, `.trellis/`, `.agents/`, `.codex/`, `.gemini/`, `.sisyphus/`, `docs/`, `lib/`, `openspec/`, `pubspec.yaml`, `analysis_options.yaml`, and `tools/`, but no root `.gitignore` was found during direct inspection.

The user intent is to close out Trellis and initialize the repository baseline. Because `.git/` already exists, the safe design is not "always run git init"; it is "verify current repository state, create missing hygiene files, document Trellis deprecation, and prepare commit readiness without committing unless explicitly requested."

## Goals / Non-Goals

**Goals:**
- Verify git repository state and only initialize if `.git/` is absent.
- Add a root `.gitignore` suitable for Dart/OpenSpec planning and future Flutter/Dart implementation.
- Preserve OpenSpec specs, archived changes, docs, public Dart contracts, tools, and agent instructions as durable project history.
- Inventory Trellis remnants and move workflow authority from Trellis to OpenSpec without deleting potentially useful journals, specs, or scripts blindly.
- Update project-facing docs so future agents do not depend on Trellis as the primary workflow.
- Run validation gates after closeout changes.

**Non-Goals:**
- Creating a git commit without an explicit commit request.
- Removing `.trellis/`, `.agents/`, `.codex/`, `.gemini/`, or `.sisyphus/` wholesale without preservation review.
- Changing product runtime contracts under `lib/src` except for documentation or export corrections required by validation.
- Rewriting archived OpenSpec changes or synced specs from completed phases.
- Adding remote git configuration, pushing, or publishing.

## Decisions

### 1. Treat git initialization as idempotent

The implementation will check whether `.git/` exists before any initialization. If the repository already exists, it will report the existing state and continue with hygiene and documentation tasks.

**Alternative considered:** always run `git init`. Rejected because the current workspace already contains `.git/`, and repeated initialization is unnecessary noise.

### 2. Preserve first, prune later

Trellis-related directories will be inventoried and documented before any deletion or ignore decision. Useful project knowledge should remain in `docs/`, `openspec/`, or explicit archival notes.

**Alternative considered:** delete `.trellis/` immediately because Trellis is no longer active. Rejected because `.trellis/workspace`, `.trellis/spec/guides`, and workflow files may contain useful historical context.

### 3. OpenSpec becomes the workflow authority

Future workflow docs should point to OpenSpec proposal/apply/archive commands as the durable change mechanism. Trellis can be described as legacy context if retained.

**Alternative considered:** keep Trellis and OpenSpec as equal workflow systems. Rejected because parallel workflow authorities create contradictory instructions for future agents.

### 4. `.gitignore` should preserve source-of-truth artifacts

The ignore file should exclude generated caches, build outputs, personal editor state, logs, Python caches, Dart tooling output, and transient AI session files while preserving `openspec/`, `docs/`, `lib/`, `tools/`, root manifests, and archived specs.

**Alternative considered:** use a generic Flutter `.gitignore` unchanged. Rejected because this project also contains OpenSpec archives and AI-tool metadata that need explicit preservation or deprecation decisions.

## Risks / Trade-offs

- **[Risk] Useful Trellis knowledge is lost during closeout** -> **Mitigation:** inventory `.trellis/` first and migrate or document useful items before deletion or broad ignore rules.
- **[Risk] Generated caches enter the first tracked baseline** -> **Mitigation:** create `.gitignore` before staging any files and validate with `git status --short`.
- **[Risk] Future agents keep following obsolete Trellis instructions** -> **Mitigation:** update root workflow docs and AGENTS guidance to name OpenSpec as the active workflow authority.
- **[Risk] A commit happens without explicit approval** -> **Mitigation:** tasks stop at commit readiness and require a separate explicit commit instruction.

## Migration Plan

1. Verify OpenSpec has no active changes and all specs validate.
2. Verify git state and create or confirm repository initialization.
3. Add `.gitignore` and repository hygiene docs.
4. Inventory Trellis remnants and update workflow documentation to mark Trellis legacy/retired.
5. Run validation gates and produce a commit-readiness summary.

## Open Questions

- Should `.trellis/workspace/` journals be preserved in git, moved to docs, or ignored as personal session state?
- Should `.agents/skills/trellis-*` be retained as historical compatibility or removed after OpenSpec-only workflow docs are in place?
- What exact commit message should be used if the user later requests the first baseline commit?
