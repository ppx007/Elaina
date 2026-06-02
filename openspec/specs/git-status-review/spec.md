# git-status-review Specification

## Purpose

Define the read-only dirty-tree review contract used before repository baseline staging, deletion, or commit decisions.

## Requirements

### Requirement: Git status review MUST be read-only
The system MUST review dirty repository state using inspection-only commands before any staging, deletion, or commit operation is considered.

#### Scenario: Dirty tree review begins
- **WHEN** the user requests a review of `git status`
- **THEN** the review uses read-only status, diff, and untracked-file commands without modifying the index, working tree, remotes, or history

#### Scenario: Modifying git command is proposed during review
- **WHEN** a command would stage, unstage, delete, commit, push, publish, configure a remote, or rewrite history
- **THEN** the review rejects that command until the user gives a separate explicit request for that action

### Requirement: Git status review SHALL classify dirty entries by purpose
The system SHALL classify dirty entries into logical buckets before producing any future staging or commit plan.

#### Scenario: Post-baseline dirty entries exist
- **WHEN** OpenSpec artifacts, Dart/lib/tooling files, workflow migration files, Trellis remnants, and possible user edits appear together in status output
- **THEN** the review groups them by purpose rather than relying only on Git status codes

#### Scenario: Entry purpose is unclear
- **WHEN** a dirty entry cannot be confidently mapped to baseline, migration, tooling, Trellis legacy, or user/preexisting work
- **THEN** the review flags it for explicit follow-up before it can be included in any staging plan

### Requirement: Git status review MUST define do-not-stage boundaries
The system MUST produce an explicit do-not-stage boundary list before recommending any future staging plan.

#### Scenario: Local-only or generated entries are present
- **WHEN** credentials, `.env*`, personal IDE state, caches, logs, build output, generated artifacts, local session files, unrelated experiments, or unresolved Trellis remnants are found
- **THEN** the review marks them as not eligible for staging without separate approval or cleanup

### Requirement: Git status review SHALL produce an advisory atomic commit plan
The system SHALL produce a future commit plan that keeps unrelated concerns separate while remaining advisory until the user explicitly requests staging or commit creation.

#### Scenario: Classification is complete
- **WHEN** dirty entries have been grouped and do-not-stage boundaries are recorded
- **THEN** the review recommends ordered atomic commit groups with file scopes, rationale, dependencies, and residual risks

#### Scenario: User has not requested commit creation
- **WHEN** the advisory commit plan is complete
- **THEN** the review stops at handoff and does not stage or commit files
