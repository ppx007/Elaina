## Why

Markdown diagnostics currently fail with `No LSP server configured for extension: .md` even though Markdown LSP binaries are available on the machine. The active user-level OpenCode config has an `lsp` section, but it does not register `.md` or `.markdown`, so Markdown files cannot be checked through `lsp_diagnostics`.

## What Changes

- Add a Markdown LSP configuration entry to the loaded OpenCode/OMO LSP configuration.
- Update `C:\Users\q1354\.config\opencode\opencode.json` and, after diagnostics identify the OMO registry as the active lookup path, `C:\Users\q1354\.config\opencode\oh-my-openagent.jsonc`.
- Prefer an already available Markdown LSP command; use `marksman server` when `vscode-markdown-language-server --stdio` fails to initialize in the current Node environment.
- Register `.md` and `.markdown` extensions.
- Verify the configs remain valid JSON/JSONC and retry Markdown diagnostics against representative docs.
- Document fallback behavior: if OpenCode does not load the new LSP until restart, report that reload/restart is required.

## Capabilities

### New Capabilities

- `markdown-lsp-configuration`: Defines how Markdown files are registered with the OpenCode LSP configuration and verified through diagnostics.

### Modified Capabilities

None.

## Impact

- Affects user-level OpenCode/OMO configuration under `C:\Users\q1354\.config\opencode\`.
- Does not modify Elaina Dart contracts, app architecture, OpenSpec synced product specs, git history, or repository source code behavior.
- Verification will cover JSON validity and Markdown LSP diagnostics where the running OpenCode session can load the updated configuration.
