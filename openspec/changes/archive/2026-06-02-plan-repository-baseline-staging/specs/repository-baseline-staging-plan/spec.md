## ADDED Requirements

### Requirement: Repository baseline staging plan MUST be planning-only
The system MUST produce repository baseline staging guidance without staging, committing, deleting, pushing, configuring remotes, or rewriting history.

#### Scenario: Staging plan is created
- **WHEN** dirty-tree review findings are converted into a repository baseline staging plan
- **THEN** the output contains advisory groups, file scopes, messages, validation gates, and risks without modifying Git index, working tree, remotes, or history

### Requirement: Repository baseline staging plan SHALL consume archived status review findings
The system SHALL derive its initial grouping from the archived `review-git-status-baseline` status review and record any drift from current read-only status output.

#### Scenario: Archived review and current status differ
- **WHEN** current read-only status output differs from the archived status review
- **THEN** the plan records the drift and does not finalize affected staging groups until the difference is classified

### Requirement: Repository baseline staging plan SHALL define atomic commit groups
The system SHALL define atomic staging groups with file scopes, dependency order, proposed messages, and justification before any future staging request can proceed.

#### Scenario: Group has three or more files
- **WHEN** a proposed staging group contains three or more files
- **THEN** the plan includes a one-sentence justification explaining why those files belong together or splits the group further

#### Scenario: Group mixes unrelated concerns
- **WHEN** a proposed group mixes workflow metadata, Dart contracts, Trellis legacy state, user edits, or generated/local files
- **THEN** the plan splits the group or flags it for human review before staging

### Requirement: Repository baseline staging plan MUST preserve do-not-stage boundaries
The system MUST preserve the do-not-stage boundaries from the `git-status-review` spec and archived status review.

#### Scenario: Ineligible entries are present
- **WHEN** secrets, generated files, local state, unresolved Trellis remnants, unclear entries, or unrelated experiments are present
- **THEN** the plan excludes them from staging groups unless the user explicitly approves their handling
