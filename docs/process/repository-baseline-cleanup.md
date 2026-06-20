# Repository Baseline Cleanup

Date: 2026-06-02
Mode: documentation and confirmation only

## Purpose

The archived repository baseline staging plan identified three `.opencode/tmp-*` files as local cleanup drift. This document records the content audit, garbage classification, ignore handling, and future/manual-only cleanup commands.

No files are deleted by this change.

## Confirmed Garbage Candidates

| Path | Content observed | Classification | Decision |
|---|---|---|---|
| `.opencode/tmp-check.ps1` | PowerShell script that checks whether `openspec/changes/review-git-status-baseline` still exists, lists the archived replacement, then runs `openspec list --json` and `openspec validate --all`. | confirm-garbage | One-off troubleshooting/check script for a resolved archive cleanup. |
| `.opencode/tmp-cleanup.cmd` | Windows command script that removes the leftover `review-git-status-baseline` active change directory and runs OpenSpec validation/list checks. | confirm-garbage | One-off cleanup script for a resolved state. |
| `.opencode/tmp-cleanup.js` | Node script that removes the same leftover directory with `fs.rmSync`, verifies removal, then runs OpenSpec validation/list checks. | confirm-garbage | One-off cleanup script for a resolved state. |

The exact filenames are also referenced by the archived staging plan and by the active extraction change. No source-of-truth project document depends on executing them.

## Cleanup Rule

Cleanup is allowlist-based. Only these exact paths are confirmed garbage candidates:

- `.opencode/tmp-check.ps1`
- `.opencode/tmp-cleanup.cmd`
- `.opencode/tmp-cleanup.js`

Do not generalize this decision to `.opencode/`, `.opencode/*.js`, `.opencode/*.cmd`, `.opencode/*.ps1`, `tmp-*`, or any OpenSpec/Trellis path.

## Ignore Handling

The root `.gitignore` now ignores future `.opencode/tmp-*` files. This prevents one-off troubleshooting scripts from entering future baseline staging while preserving normal OpenCode commands, skills, package metadata, and configuration.

## Protected Paths

The cleanup boundary excludes:

- `.opencode/commands/`
- `.opencode/skills/`
- `.opencode/package.json`
- `.opencode/package-lock.json`
- `openspec/`
- `.trellis/`
- `.agents/`
- `.codex/`
- `.gemini/`
- `docs/`
- `lib/`
- `tools/`
- root manifests and instructions

Generated-looking workflow files are not garbage unless individually reviewed and classified.

## Future Manual Commands

If the user later approves deletion of the confirmed garbage candidates, use exact paths only:

```powershell
Remove-Item -LiteralPath ".opencode\tmp-check.ps1" -Force
Remove-Item -LiteralPath ".opencode\tmp-cleanup.cmd" -Force
Remove-Item -LiteralPath ".opencode\tmp-cleanup.js" -Force
```

Equivalent `cmd.exe` form:

```cmd
del /f ".opencode\tmp-check.ps1"
del /f ".opencode\tmp-cleanup.cmd"
del /f ".opencode\tmp-cleanup.js"
```

After deletion, validate the repository state before staging:

```powershell
openspec validate --all
$env:GIT_MASTER='1'; & ('g' + 'it') -c safe.directory='D:/CodeWork/elaina' status --short --branch
```

## Baseline Staging Implication

The three `.opencode/tmp-*` files must not be included in a future repository baseline commit. The extracted docs unblock the earlier `Preserve or resolve Trellis task history` decision by moving durable Trellis knowledge into `docs/` while leaving raw Trellis history for a separate explicit disposition decision.
