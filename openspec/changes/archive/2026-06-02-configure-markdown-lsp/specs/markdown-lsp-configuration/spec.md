## ADDED Requirements

### Requirement: Markdown LSP configuration SHALL register Markdown extensions
The loaded OpenCode/OMO LSP configuration SHALL map Markdown file extensions to an installed Markdown language server.

#### Scenario: Markdown diagnostics are requested
- **WHEN** diagnostics are requested for a `.md` or `.markdown` file
- **THEN** the LSP registry includes a Markdown server entry for that extension

### Requirement: Markdown LSP configuration SHALL use an available command
The Markdown LSP entry SHALL use a command that is available on the current machine.

#### Scenario: Preferred Markdown server is available
- **WHEN** `vscode-markdown-language-server` is available on PATH
- **THEN** the Markdown LSP entry uses `vscode-markdown-language-server --stdio`

#### Scenario: Preferred Markdown server cannot be used
- **WHEN** `vscode-markdown-language-server` cannot be resolved or launched
- **THEN** the Markdown LSP entry uses `marksman server` as the fallback command

### Requirement: Markdown LSP configuration MUST preserve unrelated OpenCode and OMO settings
The configuration change MUST NOT alter unrelated OpenCode provider, MCP, plugin, OMO agent, category, or non-Markdown LSP settings.

#### Scenario: User config is updated
- **WHEN** the Markdown LSP entry is inserted into user-level OpenCode or OMO config files
- **THEN** all existing non-Markdown configuration entries remain semantically unchanged

### Requirement: Markdown LSP configuration SHALL be verified after editing
The system SHALL verify JSON validity and retry Markdown diagnostics after adding the Markdown LSP entry.

#### Scenario: Configuration parses successfully
- **WHEN** the user-level OpenCode config is edited
- **THEN** it parses as valid JSON before diagnostics are retried

#### Scenario: Running session has not reloaded LSP config
- **WHEN** Markdown diagnostics still report no `.md` server after a valid config edit
- **THEN** the result states that OpenCode likely requires a restart or reload before retrying diagnostics
