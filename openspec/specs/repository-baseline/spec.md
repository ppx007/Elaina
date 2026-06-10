# repository-baseline Specification

## Purpose
TBD - created by archiving change finalize-repository-baseline. Update Purpose after archive.
## Requirements
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

### Requirement: Bangumi runtime MUST remain optional enrichment
The repository baseline SHALL preserve the architecture rule that Bangumi runtime behavior is optional metadata/progress enrichment and MUST NOT become a prerequisite for core playback, subtitle runtime, local media handoff, Dandanplay, RSS, BT, online-rule, or diagnostics flows.

#### Scenario: Bangumi runtime is unavailable
- **WHEN** Bangumi subject lookup, auth session, or progress sync is unavailable
- **THEN** validation still proves core playback and non-Bangumi runtime slices can operate without Bangumi dependencies

### Requirement: Dandanplay runtime MUST remain optional enrichment
The repository baseline SHALL preserve the architecture rule that Dandanplay runtime behavior is optional danmaku-source enrichment and MUST NOT become a prerequisite for core playback, subtitle runtime, local media handoff, Bangumi metadata/progress, RSS, BT, online-rule, UI, native player, or diagnostics flows.

#### Scenario: Dandanplay runtime is unavailable
- **WHEN** Dandanplay match, search, comment retrieval, or comment posting is unavailable
- **THEN** validation still proves core playback and non-Dandanplay runtime slices can operate without Dandanplay dependencies

### Requirement: Basic danmaku runtime MUST remain a playback overlay capability
The repository baseline SHALL preserve the architecture rule that basic danmaku runtime behavior is a player-clock-driven playback overlay capability and MUST NOT become a prerequisite for Dandanplay provider availability, Bangumi metadata/progress, subtitle runtime, RSS, BT, online-rule, network policy, storage migration, Flutter UI, Matrix4 advanced captions, diagnostics, or native player implementations.

#### Scenario: Basic danmaku runtime is unavailable
- **WHEN** basic danmaku comments, filters, density policy, or frame resolution are unavailable
- **THEN** validation still proves core playback, subtitle runtime, Dandanplay provider runtime, and non-danmaku runtime slices can operate without basic danmaku dependencies

### Requirement: Video detail runtime MUST remain optional Domain enrichment
The repository baseline SHALL preserve the architecture rule that video detail runtime behavior is optional Domain/UI enrichment and MUST NOT become a prerequisite for core playback, player adapter availability, media scanning, subtitle provider runtime, RSS engine, seasonal indexing, BT streaming, online-rule runtime, network policy, storage migration, diagnostics, or native player implementations.

#### Scenario: Video detail runtime is unavailable
- **WHEN** detail metadata, provider bindings, continue-watching state, or follow state are unavailable
- **THEN** validation still proves core playback, provider runtimes, subtitle runtime, danmaku runtime, media-library contracts, and non-detail runtime slices can operate without video detail runtime dependencies

### Requirement: Video detail runtime MUST NOT bypass layer boundaries
The repository baseline SHALL require Step 13 video detail runtime validation to reject direct UI-to-provider access, UI-to-storage access, ProviderGateway internals in UI/detail surfaces, concrete Flutter page dependencies in Domain, media scanner ownership, RSS/seasonal ownership, BT ownership, online-rule ownership, network client ownership, and native player binding ownership.

#### Scenario: Boundary checker scans detail runtime
- **WHEN** Step 13 validation runs
- **THEN** forbidden cross-layer imports and later-phase implementation terms are rejected before the change is reported ready

### Requirement: Repository baseline SHALL keep media-library runtime optional and isolated
The repository baseline SHALL treat the Step 14 media-library runtime as optional Domain/runtime enrichment that must not become a prerequisite for core playback, video detail, subtitle provider, RSS, seasonal indexer, BT, online-rule, network, diagnostics, storage migration, or native-player implementation.

#### Scenario: Later slices are absent
- **WHEN** subtitle providers, RSS engine, seasonal indexer, BT streaming, online-rule runtime, diagnostics center, network policy, and native-player adapters are not implemented
- **THEN** the media-library runtime can still scan deterministic candidates, import catalog state, expose history/bindings, and route local playback through handoff contracts

### Requirement: Repository baseline SHALL validate Step 14 boundary terms
The repository baseline SHALL include validation for media-library runtime files that rejects later-phase and concrete implementation dependencies while allowing Domain media, cache invalidation, and playback handoff contracts.

#### Scenario: Boundary checker runs
- **WHEN** the Step 14 media-library runtime checker scans project files
- **THEN** forbidden dependencies on concrete UI, ProviderGateway internals, storage implementations, subtitle provider, RSS, seasonal, BT, online-rule, network, diagnostics, MPV/VLC, or native-player bindings fail validation

