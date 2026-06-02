## ADDED Requirements

### Requirement: Repository baseline SHALL verify git state before initialization
The system SHALL verify whether the workspace is already a git repository before running initialization commands.

#### Scenario: Git metadata already exists
- **WHEN** `.git/` exists at the workspace root
- **THEN** the repository baseline flow records the existing git state and does not run a redundant initialization command

#### Scenario: Git metadata is absent
- **WHEN** `.git/` is absent at the workspace root
- **THEN** the repository baseline flow initializes a git repository without staging or committing files automatically

### Requirement: Repository baseline SHALL define root ignore hygiene
The system SHALL define a root `.gitignore` that excludes generated Dart, Flutter, Python, IDE, OS, log, build, and cache artifacts while preserving project source-of-truth files.

#### Scenario: Generated files exist
- **WHEN** Dart tooling, Flutter build output, Python caches, editor state, logs, or temporary files are present
- **THEN** `.gitignore` excludes them from repository tracking

#### Scenario: Source-of-truth files exist
- **WHEN** OpenSpec specs, archived changes, docs, lib contracts, tools, root manifests, or agent instructions are present
- **THEN** `.gitignore` does not hide them from repository tracking by default

### Requirement: Repository baseline SHALL close out Trellis safely
The system SHALL inventory Trellis remnants and mark Trellis as legacy or retired before deleting, ignoring, or migrating Trellis-managed content.

#### Scenario: Trellis directory remains
- **WHEN** `.trellis/` exists in the workspace
- **THEN** the closeout flow records its relevant specs, scripts, tasks, and workspace history before deciding whether to preserve, migrate, or ignore them

### Requirement: Repository baseline SHALL make OpenSpec the workflow authority
The system SHALL update project-facing workflow documentation so future changes route through OpenSpec proposal, apply, validate, and archive flows rather than Trellis commands.

#### Scenario: Workflow documentation references Trellis as primary
- **WHEN** docs or agent instructions describe Trellis as the active workflow authority
- **THEN** the repository baseline flow updates them to identify OpenSpec as the active workflow and Trellis as legacy context

### Requirement: Repository baseline MUST validate before commit readiness
The system MUST run OpenSpec validation, Dart analysis, and available project checker scripts before reporting the repository as ready for a baseline commit.

#### Scenario: Validation passes
- **WHEN** OpenSpec validation, Dart analysis, and project checkers pass
- **THEN** the repository baseline flow may report commit readiness without creating a commit

#### Scenario: Validation fails
- **WHEN** any validation gate fails
- **THEN** the repository baseline flow reports the failing gate and does not report commit readiness

### Requirement: Repository baseline MUST NOT commit without explicit approval
The system MUST NOT create a git commit, configure a remote, push, or publish repository state unless the user explicitly requests that action.

#### Scenario: Baseline files are ready
- **WHEN** repository hygiene, Trellis closeout docs, and validation gates are complete
- **THEN** the flow provides a commit checklist and waits for an explicit commit request
