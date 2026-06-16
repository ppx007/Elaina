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

### Requirement: Repository baseline SHALL keep subtitle-provider runtime optional and isolated
The repository baseline SHALL treat the Step 15 subtitle-provider runtime as optional Domain/provider enrichment that must not become a prerequisite for core playback, media library, video detail, RSS, seasonal indexer, BT, online-rule, diagnostics, advanced caption rendering, storage migration, or native-player implementation.

#### Scenario: Later slices are absent
- **WHEN** RSS engine runtime, seasonal indexer, BT streaming, online-rule runtime, diagnostics center, advanced caption rendering, storage implementations, and native-player adapters are not implemented
- **THEN** the subtitle-provider runtime can still search deterministic provider candidates, reuse subtitle cache contracts, retrieve subtitle files, and prepare basic parser handoff requests

### Requirement: Repository baseline SHALL validate Step 15 boundary terms
The repository baseline SHALL include validation for subtitle-provider runtime files that rejects later-phase and concrete implementation dependencies while allowing Provider subtitle, Domain subtitle discovery, cache contract, and basic subtitle parser handoff contracts.

#### Scenario: Boundary checker runs
- **WHEN** the Step 15 subtitle-provider runtime checker scans project files
- **THEN** forbidden dependencies on concrete UI, storage implementations, network clients, scraping, captcha automation, RSS, seasonal, BT, online-rule, diagnostics, advanced captions, MPV/VLC, or native-player bindings fail validation

### Requirement: Repository baseline SHALL keep RSS engine runtime optional and isolated
The repository baseline SHALL treat the Step 16 RSS engine runtime as optional Domain/provider enrichment that must not become a prerequisite for seasonal indexer, RSS auto-download, BT streaming, online-rule runtime, diagnostics center, concrete UI, network implementation, storage migration, or native-player implementation.

#### Scenario: Later consumers are absent
- **WHEN** seasonal indexer runtime, RSS auto-download policy execution, BT streaming, online-rule runtime, diagnostics center, concrete network clients, concrete storage implementations, and native-player adapters are not implemented
- **THEN** the RSS engine runtime can still register deterministic feed sources, project due refreshes, refresh through feed contracts, persist accepted items, preserve cursor metadata, and emit accepted feed updates

### Requirement: Repository baseline SHALL validate Step 16 boundary terms
The repository baseline SHALL include validation for RSS engine runtime files that rejects later-phase and concrete implementation dependencies while allowing Domain RSS, Provider RSS, ProviderGateway result, and RSS feed storage contracts.

#### Scenario: Boundary checker runs
- **WHEN** the Step 16 RSS engine runtime checker scans project files
- **THEN** forbidden dependencies on concrete UI, concrete HTTP clients, network implementation, yuc.wiki-specific scraping, seasonal runtime, Bangumi match workers, RSS auto-download execution, BT task creation, online-rule parsing, diagnostics, MPV/VLC, or native-player bindings fail validation

### Requirement: Repository baseline SHALL keep seasonal indexer runtime optional and isolated
The repository baseline SHALL treat the Step 17 seasonal indexer runtime as optional Domain/provider enrichment that must not become a prerequisite for RSS engine operation, RSS auto-download, BT streaming, online-rule runtime, diagnostics center, concrete UI, network implementation, storage migration, or native-player implementation.

#### Scenario: Later slices are absent
- **WHEN** RSS auto-download policy execution, BT streaming, online-rule runtime, diagnostics center, concrete network clients, concrete storage implementations, UI pages, and native-player adapters are not implemented
- **THEN** the seasonal indexer runtime can still consume deterministic RSS accepted items, normalize seasonal catalog entries, queue Bangumi match work, and preserve user-confirmed binding priority through existing contracts

### Requirement: Repository baseline SHALL validate Step 17 boundary terms
The repository baseline SHALL include validation for seasonal indexer runtime files that rejects later-phase and concrete implementation dependencies while allowing Domain seasonal, Domain RSS, provider Bangumi, provider result, cache invalidation, and seasonal storage contracts.

#### Scenario: Boundary checker runs
- **WHEN** the Step 17 seasonal indexer runtime checker scans project files
- **THEN** forbidden dependencies on concrete UI, concrete HTTP clients, network implementation, yuc.wiki-specific scraping, crawlers, RSS auto-download execution, BT task creation, online-rule parsing, diagnostics, MPV/VLC, or native-player bindings fail validation

### Requirement: Repository baseline SHALL keep BT task core runtime optional and isolated
The repository baseline SHALL treat the Step 18 BT task core runtime as optional Streaming/Domain orchestration that must not become a prerequisite for core playback, virtual media stream serving, piece-priority scheduling, timeline overlay rendering, RSS auto-download, online-rule runtime, diagnostics center, concrete UI, concrete network implementation, storage migration, or native-player implementation.

#### Scenario: Later BT playback slices are absent
- **WHEN** virtual media stream runtime, piece-priority scheduler runtime, timeline overlay runtime, concrete torrent engines, concrete UI pages, diagnostics center, and native-player adapters are not implemented
- **THEN** the BT task core runtime can still create deterministic tasks, persist metadata and file state, route lifecycle commands through adapter contracts, and expose replayable task projections

### Requirement: Repository baseline SHALL validate Step 18 boundary terms
The repository baseline SHALL include validation for BT task core runtime files that rejects later Phase 4 features and concrete implementation dependencies while allowing Streaming BT task contracts, storage task contracts, cache invalidation contracts, and deterministic adapter fixtures.

#### Scenario: Boundary checker runs
- **WHEN** the Step 18 BT task core runtime checker scans project files
- **THEN** forbidden dependencies on concrete UI, concrete torrent engines, FFI, socket/range servers, virtual stream serving, piece-priority scheduler runtime, timeline overlay rendering, RSS auto-download execution, online-rule parsing, diagnostics, network implementation, storage migration, MPV/VLC, or native-player bindings fail validation

### Requirement: Repository baseline SHALL keep virtual media stream runtime optional and isolated
The repository baseline SHALL treat the Step 19 virtual media stream runtime as optional Streaming/Playback handoff orchestration that must not become a prerequisite for piece-priority scheduling, timeline overlay rendering, RSS auto-download, online-rule runtime, diagnostics center, concrete UI, concrete network implementation, storage migration, concrete torrent engines, or native-player implementation.

#### Scenario: Later BT playback slices are absent
- **WHEN** piece-priority scheduler runtime, timeline overlay runtime, concrete range servers, concrete torrent engines, concrete UI pages, diagnostics center, and native-player adapters are not implemented
- **THEN** the virtual media stream runtime can still create deterministic stream descriptors, persist lifecycle and buffered range state, publish invalidation payloads, and expose playback handoff projections

### Requirement: Repository baseline SHALL validate Step 19 boundary terms
The repository baseline SHALL include validation for virtual media stream runtime files that rejects later Phase 4 features and concrete implementation dependencies while allowing Streaming virtual stream contracts, BT task projections, storage contracts, cache invalidation contracts, and playback source handoff contracts.

#### Scenario: Boundary checker runs
- **WHEN** the Step 19 virtual media stream runtime checker scans project files
- **THEN** forbidden dependencies on concrete UI, concrete torrent engines, FFI, sockets, range servers, pipe servers, filesystem byte reads, piece-priority scheduler runtime, timeline overlay rendering, RSS auto-download execution, online-rule parsing, diagnostics, network implementation, storage migration, MPV/VLC, or native-player bindings fail validation

### Requirement: Repository baseline SHALL keep piece priority scheduler runtime optional and isolated
The repository baseline SHALL treat the Step 20 piece priority scheduler runtime as optional Streaming orchestration that must not become a prerequisite for timeline overlay rendering, RSS auto-download, online-rule runtime, diagnostics center, concrete UI, concrete network implementation, storage migration, concrete torrent engines, concrete byte-serving implementations, or native-player implementation.

#### Scenario: Later BT playback slices are absent
- **WHEN** timeline overlay runtime, concrete range servers, concrete torrent engines, concrete UI pages, diagnostics center, and native-player adapters are not implemented
- **THEN** the piece priority scheduler runtime can still generate deterministic plans, persist profile/plan/rule/application state, publish invalidation payloads, and expose read-only scheduler projections

### Requirement: Repository baseline SHALL validate Step 20 boundary terms
The repository baseline SHALL include validation for piece priority scheduler runtime files that rejects later Phase 4 timeline features and concrete implementation dependencies while allowing Streaming scheduler contracts, BT task projections, virtual stream projections, storage contracts, cache invalidation contracts, and deterministic adapter fixtures.

#### Scenario: Boundary checker runs
- **WHEN** the Step 20 piece priority scheduler runtime checker scans project files
- **THEN** forbidden dependencies on concrete UI, concrete torrent engines, FFI, sockets, range servers, pipe servers, filesystem byte reads, timeline overlay rendering, RSS auto-download execution, online-rule parsing, diagnostics, network implementation, storage migration, MPV/VLC, media-kit, platform channels, or native-player bindings fail validation

### Requirement: Step 21 timeline overlay runtime baseline
The repository SHALL treat Phase 4 Step 21 timeline overlay runtime as an optional, isolated read-model layer over playback, BT, virtual stream, and scheduler projections.

#### Scenario: Core playback remains available without overlay runtime
- **WHEN** timeline overlay runtime is unavailable
- **THEN** core playback, BT task runtime, virtual stream runtime, and piece priority scheduler runtime SHALL remain usable.

### Requirement: Step 21 boundary validation
The repository SHALL include validation that rejects Step 21 timeline overlay runtime leakage into UI rendering, playback control, concrete IO, native player integration, scheduler mutation, BT mutation, diagnostics, or Phase 5 features.

#### Scenario: Checker rejects rendering dependencies
- **WHEN** the Step 21 boundary checker scans timeline overlay runtime files
- **THEN** it SHALL fail if those files import Flutter widget/rendering packages or native player dependencies.

### Requirement: Step 22 video enhancement runtime baseline
The repository SHALL treat Phase 5 Step 22 video enhancement pipeline runtime as an optional, isolated Playback runtime layer over declarative enhancement profile, capability, storage, and invalidation contracts.

#### Scenario: Core playback remains available without enhancement runtime
- **WHEN** video enhancement pipeline runtime is unavailable
- **THEN** core playback, player adapter contracts, AVSyncGuard contracts, timeline overlay runtime, and non-enhancement runtime slices SHALL remain usable

### Requirement: Step 22 video enhancement boundary validation
The repository SHALL include validation that rejects Step 22 video enhancement runtime leakage into concrete renderer bindings, shader bundle execution, platform channels, UI rendering, AVSyncGuard policy implementation, diagnostics, network/RSS automation, captions, fallback adapter behavior, or later-phase implementation.

#### Scenario: Checker rejects native renderer dependencies
- **WHEN** the Step 22 boundary checker scans video enhancement runtime files
- **THEN** it SHALL fail if those files import or invoke concrete MPV/VLC/media-kit bindings, shader bundle execution, platform channels, Flutter widget/rendering packages, diagnostics center behavior, network/RSS automation, captions, fallback adapter implementation, or AVSyncGuard drift policy

### Requirement: Step 23 AV sync guard runtime baseline
The repository SHALL treat Phase 5 Step 23 AV sync guard runtime as an optional, isolated Playback runtime layer over declarative guard health, degradation, storage, and invalidation contracts.

#### Scenario: Core playback remains available without AV sync guard runtime
- **WHEN** AV sync guard runtime is unavailable
- **THEN** core playback, player adapter contracts, video enhancement pipeline runtime, timeline overlay runtime, and non-AV-sync-guard runtime slices SHALL remain usable

### Requirement: Step 23 AV sync guard boundary validation
The repository SHALL include validation that rejects Step 23 AV sync guard runtime leakage into concrete MPV timing probes, native FFI bindings, VLC fallback selection, diagnostics center integration, network policy, RSS automation, WebView session handling, or Flutter rendering.

#### Scenario: Checker rejects native timing dependencies
- **WHEN** the Step 23 boundary checker scans AV sync guard runtime files
- **THEN** it SHALL fail if those files import or invoke concrete MPV property handles, libmpv/media-kit bindings, native renderer callbacks, VLC fallback selection, diagnostics center behavior, network policy modules, RSS automation, WebView challenge handling, or Flutter widget/rendering packages

### Requirement: Repository baseline SHALL record Step 24 advanced caption rendering runtime
The system SHALL include a Step 24 baseline entry documenting the advanced caption rendering runtime/bootstrap acceptance layer, its typed projection and action result contracts, and its scope-gate boundary.

#### Scenario: Step 24 runtime baseline entry exists
- **WHEN** the repository baseline spec is read
- **THEN** a Step 24 advanced caption rendering runtime entry is present with bootstrap, projection, restart, and boundary descriptions

### Requirement: Repository baseline SHALL enforce Step 24 runtime boundary
The system SHALL require Step 24 runtime code to import only cache invalidation bus, advanced caption storage contracts, advanced caption rendering, and capability matrix — rejecting imports of native, FFI, VLC, renderer bindings, Flutter UI, diagnostics, network, RSS, WebView, and online rule modules.

#### Scenario: Boundary validation rejects out-of-scope imports
- **WHEN** the Step 24 runtime import boundary is checked
- **THEN** no import of native, FFI, VLC, renderer bindings, Flutter UI, diagnostics, network, RSS, WebView, or online rule modules is found

### Requirement: Repository baseline SHALL record Step 25 VLC fallback adapter runtime
The system SHALL include a Step 25 baseline entry documenting the VLC fallback adapter runtime/bootstrap acceptance layer, its typed projection and action result contracts, and its scope-gate boundary.

#### Scenario: Step 25 runtime baseline entry exists
- **WHEN** the repository baseline spec is read
- **THEN** a Step 25 VLC fallback adapter runtime entry is present with bootstrap, projection, restart, and boundary descriptions

### Requirement: Repository baseline SHALL enforce Step 25 runtime boundary
The system SHALL require Step 25 runtime code to import only cache invalidation bus, fallback adapter storage contracts, fallback adapter, and capability matrix — rejecting imports of VLC-specific packages, native FFI, PlayerAdapter invocations, Flutter widgets, diagnostics, network, RSS, WebView, captions, and online rule modules.

#### Scenario: Boundary validation rejects out-of-scope imports
- **WHEN** the Step 25 runtime import boundary is checked
- **THEN** no import of VLC-specific packages, native FFI, PlayerAdapter method invocations, Flutter widgets, diagnostics, network, RSS, WebView, captions, or online rule modules is found

### Requirement: Repository baseline SHALL record Step 26 RSS auto-download policy runtime boundary
The repository baseline SHALL record that Step 26 adds the RSS auto-download policy runtime acceptance layer (bootstrap, scoped projections, typed outcomes, restart replay, dispose/unavailable/capability gates) and that concrete torrent engines, libtorrent bindings, FeedFetcher/FeedParser duplication, online source rule runtimes, WebView challenge handling, captcha solving, DNS/network policy, diagnostics center actions, mandatory automation startup, yuc.wiki special-casing, and Flutter rendering remain outside the Step 26 slice boundary.

#### Scenario: Step 26 runtime boundary is documented
- **WHEN** future changes reference which capabilities Step 26 introduced
- **THEN** the repository baseline records that Step 26 added RssAutoDownloadPolicyRuntimeBootstrap, RssAutoDownloadPolicyRuntime, typed outcome types, projection types, and restart replay without introducing concrete torrent engine, duplicate RSS engine, mandatory automation, or UI dependencies

#### Scenario: Step 26 runtime boundary validation is enforced
- **WHEN** Step 26 runtime, test, and checker files are validated against boundary constraints
- **THEN** no FeedFetcher, FeedParser, libtorrent, WebView, captcha, DNS, proxy, diagnostics, online rule runtime, or Flutter dependency is present in the runtime slice

### Requirement: Repository baseline SHALL record Step 27 online rule source runtime boundary
The repository baseline SHALL record that Step 27 adds the online rule source runtime acceptance layer (bootstrap, scoped projections, typed outcomes, restart replay, disable/reenable, dispose/unavailable/capability gates) and that gateway page retrieval, network client, WebView challenge handling, captcha solving, DNS/network policy, diagnostics center actions, Flutter rendering, yuc.wiki special-casing, libtorrent bindings, registerSource, and refreshManifest remain outside the Step 27 slice boundary.

#### Scenario: Step 27 runtime boundary is documented
- **WHEN** future changes reference which capabilities Step 27 introduced
- **THEN** the repository baseline records that Step 27 added OnlineRuleSourceRuntimeBootstrap, OnlineRuleSourceRuntime, typed outcome types, projection types, and restart replay without introducing gateway, network, WebView, captcha, DNS, proxy, diagnostics, or UI dependencies

#### Scenario: Step 27 runtime boundary validation is enforced
- **WHEN** Step 27 runtime, test, and checker files are validated against boundary constraints
- **THEN** no gateway client, network client, WebView, captcha, DNS client, proxy server, diagnostics center, Flutter widget, libtorrent, registerSource, or refreshManifest dependency is present in the runtime slice

### Requirement: Repository baseline SHALL record Step 28 WebView session backfill runtime boundary
The repository baseline SHALL record that Step 28 adds a WebView session backfill runtime acceptance layer with bootstrap composition, typed outcomes, store-backed projections, restart replay, manual-only gates, and same-origin artifact replay.

#### Scenario: Step 28 runtime boundary is documented
- **WHEN** future work references Phase 6 WebView verification backfill
- **THEN** the repository baseline identifies `WebViewSessionBackfillRuntimeBootstrap`, `WebViewSessionBackfillRuntime`, runtime action results, projections, and boundary checkers as the Step 28 scope

### Requirement: Repository baseline SHALL validate Step 28 no-automation scope
The repository baseline SHALL require validation that Step 28 runtime files reject automatic captcha solving, challenge bypass, credential guessing, bot completion, headless automation, hidden browser interaction, shared profile cookie access, cross-origin reuse, concrete WebView plugins, Flutter UI, diagnostics behavior, network policy execution, RSS, BT, online-rule, native, FFI, and platform channel dependencies.

#### Scenario: Step 28 checker rejects automation leakage
- **WHEN** Step 28 validation scans runtime files
- **THEN** forbidden automation, UI, diagnostics, network, and unrelated runtime terms fail validation before archive

### Requirement: Repository baseline SHALL record Step 29 network policy runtime boundary
The repository baseline SHALL record that Step 29 adds a network policy runtime acceptance layer with bootstrap composition, typed outcomes, store-backed projections, restart replay, provider assignment gates, capability gates, and invalidation publication.

#### Scenario: Step 29 runtime boundary is documented
- **WHEN** future work references Phase 6 DNS/network policy behavior
- **THEN** the repository baseline identifies `NetworkPolicyRuntimeBootstrap`, `NetworkPolicyRuntime`, runtime action results, projections, and boundary checkers as the Step 29 scope

### Requirement: Repository baseline SHALL validate Step 29 concrete-networking exclusions
The repository baseline SHALL require validation that Step 29 runtime files reject concrete DNS clients, DoH clients, DoT clients, proxy clients, proxy servers, PAC parsers, VPN/TUN behavior, kernel filtering, DPI, packet capture, sockets, platform network plugins, Flutter UI, native, FFI, platform channels, diagnostics implementation, provider dispatch, RSS, BT, online-rule, WebView, captcha, libtorrent, MPV, VLC, media-kit, and yuc.wiki dependencies.

#### Scenario: Step 29 checker rejects networking leakage
- **WHEN** Step 29 validation scans runtime files
- **THEN** forbidden networking, transport, UI, diagnostics, provider-dispatch, native, and unrelated runtime terms fail validation before archive

### Requirement: Repository baseline SHALL include Step 30 diagnostics center runtime
The repository baseline SHALL record Step 30 as the diagnostics center runtime acceptance layer that closes Phase 6 by exposing local read-only diagnostics runtime projections, typed outcomes, retention/export descriptors, redaction, and capability gates.

#### Scenario: Step 30 remains scoped
- **WHEN** Step 30 diagnostics runtime is implemented
- **THEN** it remains local and read-only, with no UI, playback control, provider mutation, network policy mutation, BT enqueue, native, FFI, platform channel, remote telemetry, or cloud upload behavior

