## 1. Confirm current state

- [x] 1.1 Re-read `C:\Users\q1354\.config\opencode\opencode.json` and confirm `lsp.markdown` is absent.
- [x] 1.2 Confirm `vscode-markdown-language-server` is available on PATH.
- [x] 1.3 Keep `marksman server` as the fallback command if the preferred command cannot be resolved or launched.

## 2. Configure Markdown LSP

- [x] 2.1 Add a `markdown` entry under the existing `lsp` object in `C:\Users\q1354\.config\opencode\opencode.json`.
- [x] 2.2 Configure the command as `marksman server` after `vscode-markdown-language-server --stdio` failed to initialize.
- [x] 2.3 Register `.md` and `.markdown` extensions.
- [x] 2.4 Preserve all unrelated OpenCode config values and avoid rewriting provider, MCP, plugin, agent, category, or existing LSP settings.
- [x] 2.5 Add the same Markdown LSP mapping to `C:\Users\q1354\.config\opencode\oh-my-openagent.jsonc` after diagnostics reported the OMO registry path.

## 3. Verify behavior

- [x] 3.1 Parse `opencode.json` as valid JSON after editing.
- [x] 3.2 Retry Markdown diagnostics on representative `.md` files from `docs/` and `openspec/specs/`.
- [x] 3.3 If the running session still reports no `.md` server, report that OpenCode likely needs restart or reload and provide the exact retry command/action.
- [x] 3.4 Run `openspec validate configure-markdown-lsp` after artifacts are complete.

## 4. Handoff

- [x] 4.1 Report the selected command, changed file, and verification results.
- [x] 4.2 State whether a restart/reload is still required before Markdown diagnostics can pass in the current session.
