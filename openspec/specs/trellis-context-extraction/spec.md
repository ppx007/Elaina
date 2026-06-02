# trellis-context-extraction Specification

## Purpose
Define how legacy Trellis context is inventoried, promoted into durable docs, and protected from accidental cleanup while local garbage candidates are confirmed with evidence.
## Requirements
### Requirement: Trellis context extraction SHALL inventory before cleanup
The system SHALL inventory Trellis task, workspace, workflow, guide, and temporary tool files before extracting or cleaning any content.

#### Scenario: Extraction begins
- **WHEN** Trellis legacy content is considered for docs extraction or cleanup
- **THEN** the system records each relevant source path, category, target action, and rationale before making file changes

### Requirement: Trellis context extraction SHALL promote durable knowledge to docs
The system SHALL extract reusable Trellis decisions, engineering guides, and project constraints into stable `docs/` files.

#### Scenario: Durable decision is found in task history
- **WHEN** a Trellis task PRD contains reusable architecture, workflow, or baseline-staging decisions
- **THEN** the system summarizes the decision in a docs target and links or references the source path for traceability

#### Scenario: Session trace is not generally useful
- **WHEN** task JSONL, workspace journal, or execution trace content is only session-local
- **THEN** the system keeps it out of docs and classifies it as legacy/local unless the user approves another disposition

### Requirement: Trellis context extraction MUST protect operational project assets
The system MUST NOT classify operational OpenSpec, Trellis script, docs, source, root manifest, or user-authored project assets as garbage.

#### Scenario: Cleanup candidates are reviewed
- **WHEN** cleanup candidates include files outside confirmed temporary patterns
- **THEN** the system blocks cleanup until the file is manually reviewed and classified

### Requirement: Local garbage confirmation SHALL be evidence-based
The system SHALL confirm generated local garbage by name, location, content, and context before recommending deletion or ignore rules.

#### Scenario: `.opencode/tmp-*` files are present
- **WHEN** `.opencode/tmp-*` files contain only generated cleanup/check logic from prior troubleshooting
- **THEN** the system may classify them as confirmed garbage and document future cleanup steps without touching unrelated `.opencode` commands or skills
