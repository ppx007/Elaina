## MODIFIED Requirements

### Requirement: Repository baseline staging plan SHALL consume archived status review findings
The system SHALL derive its initial grouping from the archived `review-git-status-baseline` status review and record any drift from current read-only status output, including drift introduced by completed cleanup, documentation extraction, synced OpenSpec specs, and active proposal state.

#### Scenario: Archived review and current status differ
- **WHEN** current read-only status output differs from the archived status review
- **THEN** the plan records the drift and does not finalize affected staging groups until the difference is classified

#### Scenario: Completed cleanup changes affect status
- **WHEN** previously unresolved temp files, Trellis extraction docs, synced specs, or newly archived changes alter the dirty-tree shape
- **THEN** the refreshed plan records whether each change is resolved, still blocked, or newly eligible for a future staging group

### Requirement: Repository baseline staging plan MUST preserve do-not-stage boundaries
The system MUST preserve the do-not-stage boundaries from the `git-status-review` spec and archived status review, and MUST also exclude active OpenSpec change directories until those changes are archived.

#### Scenario: Ineligible entries are present
- **WHEN** secrets, generated files, local state, unresolved Trellis remnants, unclear entries, unrelated experiments, ignored temp files, or active OpenSpec change directories are present
- **THEN** the plan excludes them from staging groups unless the user explicitly approves their handling

## ADDED Requirements

### Requirement: Repository baseline staging plan MUST require selective staging safeguards
The system MUST require pathspec-driven or patch-based staging safeguards before any future baseline commit execution.

#### Scenario: Future staging is requested
- **WHEN** a future request asks to stage or commit a baseline group
- **THEN** the plan requires `git add --dry-run` or equivalent preview for explicit pathspecs before mutating the index

#### Scenario: Blanket staging command is proposed
- **WHEN** `git add -A`, `git add .`, `git commit -a`, or another blanket staging command is proposed for the large dirty tree
- **THEN** the plan rejects it and requires explicit per-group pathspec or patch staging instead
