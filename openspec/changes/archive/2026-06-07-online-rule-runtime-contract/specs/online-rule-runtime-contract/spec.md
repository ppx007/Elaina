## ADDED Requirements

### Requirement: Online rule runtime contract SHALL persist declarative source state
The system SHALL define durable online rule records for source manifests, manifest versions, rule sets, extraction operations, validation issues, evaluation snapshots, page retrieval outcomes, unsupported operations, and source capability state without storing browser sessions, executable script handles, concrete crawler instances, UI state, or network resolver resources.

#### Scenario: Rule manifest state is restored
- **WHEN** online rule manifests and validation history are written to Storage
- **THEN** later runtime flows can restore source identity, version state, validation decisions, and rule target definitions without depending on a concrete scraper or browser implementation

### Requirement: Online rule runtime contract SHALL validate manifests deterministically
The system SHALL define deterministic manifest validation using declarative source identity, version metadata, checksum/update metadata, target-specific rule sets, supported extraction operations, and explicit unsupported-operation failures.

#### Scenario: Manifest declares executable operations
- **WHEN** a manifest declares JavaScript, WASM, scriptlet, arbitrary code execution, unsupported selector syntax, or unsafe regex behavior
- **THEN** validation returns typed unsupported-operation outcomes and keeps the rule source disabled until the issue is resolved

### Requirement: Online rule runtime contract SHALL expose typed evaluation outcomes
The system SHALL return typed registration, validation, refresh, retrieval, extraction, unsupported-operation, disable, and capability outcomes for online rule actions instead of relying on nullable maps, thrown concrete parser exceptions, or implicit fallback behavior.

#### Scenario: Evaluation cannot produce required output
- **WHEN** a required extraction operation is missing, unsupported, or fails to produce a normalized field
- **THEN** the evaluation outcome contains a typed failure with source identity, target type, operation identity, and reason

### Requirement: Online rule runtime contract SHALL normalize target outputs
The system SHALL represent search, detail, episode, and playable-source evaluation results as normalized Domain-facing read models with source identity, target identity, extracted fields, source page URI, and validation warnings while keeping source-specific selector details inside the rule runtime boundary.

#### Scenario: Search target is evaluated
- **WHEN** a search page document satisfies a registered online rule target
- **THEN** the runtime returns normalized search result records rather than exposing raw selector matches to UI or playback layers

### Requirement: Online rule runtime contract MUST remain optional and extension-neutral
The system MUST keep concrete crawlers, source-specific scrapers, JavaScript/WASM execution, WebView challenge handling, automatic captcha solving, DNS/proxy implementation, diagnostics actions, Flutter UI, yuc.wiki-specific special cases, and mandatory online-source startup outside the online rule runtime contract slice.

#### Scenario: Online rule runtime is unsupported
- **WHEN** online rule support is unavailable, disabled, or has no valid manifest
- **THEN** local playback, manual URL playback, BT virtual stream playback, RSS refresh, media-library browsing, and core startup continue through existing contracts
