## Context

Markdown diagnostics were retried against repository docs and synced OpenSpec specs. Each call failed with `No LSP server configured for extension: .md`.

Environment inspection found Markdown language servers available on PATH:

- `vscode-markdown-language-server`
- `vscode-markdown-language-server.cmd`
- `marksman.exe`

The active user-level OpenCode config at `C:\Users\q1354\.config\opencode\opencode.json` contains an `lsp` object with entries for bash, C/C++, CSS, Go, HTML, JSON, Python, Rust, TypeScript, and YAML. It does not contain a Markdown entry. The lightweight `opencode.jsonc` only loads the `oh-my-openagent` plugin, and `oh-my-openagent.jsonc` initially contained model/category settings rather than LSP mappings.

During apply, JSON validation confirmed the `opencode.json` Markdown entry was valid, but `lsp_diagnostics` still reported no `.md` server and instructed that custom servers be configured in `oh-my-openagent.json`. That means the diagnostics tool is reading the OMO-side LSP registry for this operation, so the fix must register Markdown in `oh-my-openagent.jsonc` as well.

## Goals / Non-Goals

**Goals:**

- Register Markdown files with the LSP configuration actually used by diagnostics.
- Use an already installed Markdown LSP binary.
- Preserve the current user-level config structure and formatting style.
- Verify JSON validity after editing.
- Retry Markdown diagnostics against representative `.md` files.

**Non-Goals:**

- Installing new tools or package dependencies.
- Changing Celesteria application source code.
- Changing project OpenSpec product contracts beyond this proposal's own artifacts.
- Moving the entire OpenCode config into this repository.
- Editing provider/API secrets or unrelated config values.

## Decisions

### Use `marksman server` after the preferred server fails

The current config already uses VS Code language server commands for CSS, HTML, and JSON. `vscode-markdown-language-server` is present on PATH, so it was the first attempted command:

```json
"markdown": {
  "command": ["vscode-markdown-language-server", "--stdio"],
  "extensions": [".md", ".markdown"]
}
```

Alternative considered: `marksman server`. `marksman.exe` is also present and is a valid fallback, but it is not aligned with the existing VS Code language-server style in `opencode.json`.

During verification, `vscode-markdown-language-server` was recognized but failed during initialization with a `vscode-uri` default export mismatch under Node.js v20.19.0. The fallback decision is therefore to configure Markdown with:

```json
"markdown": {
  "command": ["marksman", "server"],
  "extensions": [".md", ".markdown"]
}
```

### Edit user-level `opencode.json` and OMO LSP config

The user-level `opencode.json` contains a visible LSP registry, so the first minimal change is adding Markdown there. However, the diagnostics tool explicitly reports that custom servers should be configured in the OMO config. Therefore `oh-my-openagent.jsonc` also needs an `lsp.markdown` entry.

Alternative considered: only edit `opencode.json`. That was insufficient in the running session because diagnostics still did not see `.md` after the valid edit.

### Verify with two outcomes

After editing, run JSON validation and retry Markdown diagnostics. If the running OpenCode session still reports no `.md` server, the likely cause is that LSP configuration is loaded at process startup; in that case the apply result should explicitly tell the user to restart/reload OpenCode and retry.

## Risks / Trade-offs

- **[Risk] The running session does not reload LSP config dynamically** -> **Mitigation:** report the exact result and require an OpenCode restart/reload if diagnostics still use the old registry.
- **[Risk] The preferred VS Code Markdown language server fails at runtime** -> **Mitigation:** use the already installed `marksman server` fallback.
- **[Risk] Editing user-level config touches unrelated secrets/settings** -> **Mitigation:** make minimal JSON-object insertions under `lsp` only; do not rewrite unrelated providers, MCPs, plugins, agents, categories, or model settings.
- **[Risk] JSON formatting or commas break config loading** -> **Mitigation:** parse the file after editing with a JSON parser before retrying diagnostics.
