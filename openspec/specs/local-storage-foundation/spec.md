# local-storage-foundation Specification

## Purpose
TBD - created by archiving change bootstrap-phase-0-foundation. Update Purpose after archive.
## Requirements
### Requirement: Storage foundation SHALL provide baseline durable state domains
The system SHALL define storage responsibilities for SQLite metadata, blob cache, media cache, user settings, migration state, media library catalog state, playback history state, provider binding state, subtitle cache state, RSS feed state, seasonal catalog state, Bangumi match queue state, BT task state, virtual media stream state, and piece priority scheduler state before feature-specific consumers are implemented.

#### Scenario: A future feature needs persistence
- **WHEN** playback history, media library items, subtitle cache records, RSS entries, seasonal entries, BT task entries, virtual stream descriptors, scheduler profiles, priority plans, provider state, or diagnostics snapshots need durable storage
- **THEN** the feature stores its state through pre-defined Storage-layer responsibilities instead of creating ad hoc persistence paths

### Requirement: Metadata persistence MUST support schema evolution
The system MUST track schema versioning and provide a migration mechanism for SQLite-backed metadata so future releases can evolve storage safely.

#### Scenario: A later version changes metadata shape
- **WHEN** a new feature introduces a schema change to persisted metadata
- **THEN** the system applies an ordered migration from the previous schema version before using the new structure

### Requirement: Storage concerns MUST remain isolated from UI and provider code
The system MUST isolate persistence and cache implementation details inside the Storage layer so other layers depend on storage contracts rather than concrete database or file layout details, including subtitle search/content cache records, RSS feed source/item/cursor/deduplication records, seasonal catalog entries, Bangumi match queue records, BT task records, virtual media stream records, and piece priority scheduler records.

#### Scenario: A provider needs cached state
- **WHEN** a provider-facing flow needs persisted or cached information
- **THEN** it accesses that information through approved Gateway and Storage-layer contracts instead of direct database, filesystem, or provider-owned cache coupling

### Requirement: Storage foundation SHALL expose media persistence repositories
The system SHALL expose storage-backed contracts for the media library catalog, playback history, and provider binding state so Domain consumers can persist and query media state through stable interfaces.

#### Scenario: Media state survives restart
- **WHEN** a media library item, playback history entry, or provider binding is written to storage
- **THEN** a later read through the corresponding repository contract returns the persisted state after application restart

### Requirement: Provider cache behavior MUST NOT bypass ProviderGateway
Provider-facing cache, retry, rate-limit, and negative-cache behavior MUST be mediated by `ProviderGateway` even when Storage-layer persistence is used underneath.

#### Scenario: A provider response is cacheable
- **WHEN** a provider-facing request produces cacheable or negative-cacheable data
- **THEN** `ProviderGateway` owns the cache policy and delegates persistence to Storage contracts without the provider directly managing cache files or database rows

### Requirement: Storage foundation SHALL expose subtitle cache contracts
The system SHALL expose storage-backed contracts for subtitle search result cache records and retrieved subtitle content cache records.

#### Scenario: Subtitle cache state survives restart
- **WHEN** subtitle search results or retrieved subtitle content are written to storage
- **THEN** a later read through subtitle cache contracts can return the stored data until its TTL expires

### Requirement: Storage foundation SHALL expose RSS feed persistence contracts
The system SHALL expose storage-backed contracts for registered feed sources, fetched feed items, feed refresh cursor metadata, and accepted feed deduplication keys.

#### Scenario: RSS feed state survives restart
- **WHEN** a feed source is registered, refreshed, and deduplicated
- **THEN** later RSS engine refreshes can read the source, cursor, item, and dedupe state through Storage contracts

### Requirement: Storage foundation SHALL expose seasonal indexer persistence contracts
The system SHALL expose storage-backed contracts for seasonal catalog entries, Bangumi match queue items, provider match candidates, and queue processing state.

#### Scenario: Seasonal queue state survives restart
- **WHEN** seasonal catalog entries and queued Bangumi match candidates are written to storage
- **THEN** later seasonal indexing and match worker flows can resume through Storage contracts without Provider-owned persistence

### Requirement: Storage foundation SHALL expose BT task persistence contracts
The system SHALL expose storage-backed contracts for BT task source records, metadata records, file selection records, transfer status snapshots, and latest task events.

#### Scenario: BT task state survives restart
- **WHEN** a BT task is created, metadata is fetched, file selections change, or lifecycle status updates
- **THEN** later BT task orchestration can resume from Storage contracts without relying on provider-owned or engine-owned persistence

### Requirement: Storage foundation SHALL expose virtual media stream persistence contracts
The system SHALL expose storage-backed contracts for virtual stream descriptors, stream lifecycle state, buffered range snapshots, and latest stream range events.

#### Scenario: Virtual stream state survives restart
- **WHEN** a virtual stream descriptor or buffered range is written to storage
- **THEN** later playback handoff and stream registry flows can read that state without querying concrete download engines or byte-serving implementations

### Requirement: Storage foundation SHALL expose piece priority scheduler persistence contracts
The system SHALL expose storage-backed contracts for scheduler strategy profiles, generated priority plans, priority plan rules, and latest plan application events.

#### Scenario: Priority scheduler state survives restart
- **WHEN** a scheduler profile or generated priority plan is written to storage
- **THEN** later scheduler flows can read that state without querying concrete download engines or platform priority APIs

### Requirement: Storage foundation SHALL expose AV sync guard persistence contracts
The system SHALL expose storage-backed contracts for AV sync guard policy configuration, latest health state, sample history metadata, and degradation decision history.

#### Scenario: AV sync guard state survives restart
- **WHEN** AV sync policy, health, sample metadata, or degradation decisions are written to Storage
- **THEN** later Playback flows can restore deterministic guard state without direct database, renderer, native plugin, diagnostics, or UI persistence coupling

#### Scenario: Runtime rebuilds projection from store after restart
- **WHEN** a new runtime instance is created for a scope that has previously stored health and degradation records
- **THEN** the runtime projection reads health and degradation data from the existing guard store contracts without requiring additional storage schema changes

#### Scenario: Runtime persists degradation decisions on accepted requests
- **WHEN** the runtime accepts a degradation request
- **THEN** the underlying deterministic guard records the degradation decision to the guard store, and the runtime projection reflects it on the next snapshot

### Requirement: Storage foundation SHALL expose advanced caption persistence contracts
The system SHALL expose storage-backed contracts for advanced caption profiles, active feature selection, dual-subtitle preferences, and latest renderer state metadata.

#### Scenario: Advanced caption state survives restart
- **WHEN** advanced caption feature toggles, selected subtitle tracks, and renderer state metadata are written to Storage
- **THEN** later playback preparation can restore advanced caption state without direct UI, renderer, or provider coupling

### Requirement: Storage foundation SHALL expose fallback adapter persistence contracts
The system SHALL expose storage-backed contracts for fallback adapter candidates, active fallback configuration, fallback selection history, and latest fallback strategy state metadata.

#### Scenario: Fallback adapter state survives restart
- **WHEN** fallback candidates, active fallback configuration, selection history, or latest fallback state metadata are written to Storage
- **THEN** later Playback flows can restore fallback strategy state without direct UI, native adapter, VLC package, or platform player coupling

### Requirement: Storage foundation SHALL expose video enhancement persistence contracts
The system SHALL expose storage-backed contracts for video enhancement profiles, active profile selection, and latest enhancement pipeline state metadata.

#### Scenario: Enhancement profile state survives restart
- **WHEN** an enhancement profile or active profile selection is written to Storage
- **THEN** later Playback flows can restore declarative enhancement intent without direct database, shader file, renderer, native plugin, or UI persistence coupling

### Requirement: Storage foundation SHALL expose RSS auto-download persistence contracts
The system SHALL expose storage-backed contracts for RSS auto-download policies, matcher rules, evaluation history, accepted candidates, rejected candidates, deduplication state, and enqueue outcomes.

#### Scenario: RSS automation state survives restart
- **WHEN** RSS auto-download policies, candidate history, or enqueue outcomes are written to Storage
- **THEN** later automation flows can restore policy state and avoid duplicate BT handoffs without direct UI, RSS fetcher, torrent engine, or platform service coupling

### Requirement: Storage foundation SHALL expose online rule runtime persistence contracts
The system SHALL expose storage-backed contracts for online rule source manifests, manifest versions, rule sets, extraction operations, validation issues, evaluation snapshots, page retrieval outcomes, unsupported operations, and source capability state.

#### Scenario: Online rule source state survives restart
- **WHEN** online rule manifests, validation issues, evaluation snapshots, or retrieval outcomes are written to Storage
- **THEN** later online rule flows can restore source state and validation decisions without direct UI, crawler, WebView, JavaScript runtime, or network resolver coupling

### Requirement: Storage foundation SHALL expose WebView session backfill persistence contracts
The system SHALL expose storage-backed contracts for WebView challenge requests, normalized session artifacts, backfill attempts, retry outcomes, artifact expiry, artifact revocation, and platform capability state.

#### Scenario: Backfill state survives restart
- **WHEN** a challenge request, captured artifact, backfill attempt, expiry, revocation, or capability state is written to Storage
- **THEN** later provider session flows can resume or reject the backfill state through Storage contracts without direct UI, WebView adapter, provider, browser profile, or database coupling

#### Scenario: Artifact is revoked
- **WHEN** a user or provider session boundary revokes a captured artifact
- **THEN** Storage records the artifact as inactive so later retry descriptors cannot attach it to provider traffic

### Requirement: Storage foundation SHALL expose network policy persistence contracts
The system SHALL expose storage-backed contracts for network policy profiles, ordered policy rules, provider policy assignments, policy evaluation snapshots, normalized block outcomes, and network policy capability state.

#### Scenario: Network policy state survives restart
- **WHEN** provider-scoped network policies, rules, assignments, evaluations, block outcomes, or capability state are written to Storage
- **THEN** later Gateway and Network flows can restore policy state without direct UI, provider, resolver, proxy, platform network plugin, or database coupling

#### Scenario: Evaluation outcome is recorded
- **WHEN** a provider-scoped network policy decision allows, annotates, falls back, or blocks a request
- **THEN** Storage records the evaluation snapshot for later diagnostics without granting diagnostics control over network behavior

### Requirement: Storage foundation SHALL expose diagnostics persistence contracts
The system SHALL expose storage-backed contracts for diagnostics event schemas, redacted diagnostics events, diagnostics snapshots, export requests, export outcomes, retention state, and diagnostics capability state.

#### Scenario: Diagnostics state survives restart
- **WHEN** diagnostics schemas, events, snapshots, exports, retention outcomes, or capability state are written to Storage
- **THEN** later diagnostics flows can restore local read-model state without direct UI, telemetry, provider, playback, network policy, BT, or database coupling

#### Scenario: Redacted event is persisted
- **WHEN** diagnostics records an event with sensitive payload keys
- **THEN** Storage receives only the redacted diagnostics record and never receives raw session artifact, authorization, cookie, token, or local secret values

### Requirement: Storage foundation SHALL provide deterministic Phase 0 composition
The system SHALL provide a deterministic `StorageFoundation` composition that exposes existing local store contracts through a single bootstrap surface without requiring concrete database, blob-cache, filesystem, platform, or migration adapters.

#### Scenario: Bootstrap storage is requested
- **WHEN** Phase 0 foundation runtime bootstrap creates storage dependencies
- **THEN** callers can access deterministic metadata, settings, media library, playback history, provider binding, RSS, automation, streaming, network policy, diagnostics, and advanced playback stores through the `StorageFoundation` interface

### Requirement: Storage bootstrap MUST remain local-first and adapter-free
The storage bootstrap MUST NOT introduce concrete SQLite drivers, remote storage, cloud sync, telemetry persistence, platform filesystem plugins, or mandatory startup migrations.

#### Scenario: Durable adapter is unavailable
- **WHEN** no production database or blob adapter has been configured
- **THEN** the deterministic storage foundation remains constructible for tests and early runtime checks without external services

### Requirement: Storage foundation SHALL persist BT runtime bootstrap state atomically
The storage foundation SHALL provide BT task storage contracts that allow Step 18 runtime bootstrap flows to persist task identity, source binding, lifecycle state, metadata availability, selected files, transfer snapshot metadata, latest event metadata, and runtime snapshot visibility as atomic task-state transitions.

#### Scenario: Runtime command changes task state
- **WHEN** BT task creation, metadata fetch, file selection, lifecycle command, status observation, or event observation changes persisted task state
- **THEN** storage records the related task, metadata, file, transfer, event, and visibility state as one coherent transition before the runtime reports the mutation as replayable

### Requirement: Storage foundation SHALL support BT runtime restart reconciliation
The storage foundation SHALL expose enough persisted BT task state for runtime bootstrap code to distinguish resumable, paused, terminal, failed, removed, and incomplete task records after restart without querying a concrete torrent engine directly.

#### Scenario: Runtime starts after process restart
- **WHEN** the BT task core runtime bootstraps from persisted storage
- **THEN** it can rebuild task projections and identify which tasks require adapter reconciliation, which are terminal, and which are not safely resumable using storage contracts rather than engine-owned persistence

### Requirement: Storage foundation SHALL version BT runtime task records
The storage foundation SHALL keep BT runtime task records compatible with schema/version evolution so later Phase 4 and diagnostics consumers can extend handoff metadata without direct database, file layout, or engine coupling.

#### Scenario: Task storage shape evolves
- **WHEN** a later change adds task handoff metadata, transfer metadata, or diagnostics metadata to BT task storage
- **THEN** schema/version handling preserves existing task records and exposes the evolved shape through Storage-layer contracts

### Requirement: Storage foundation MUST enforce BT runtime storage boundaries
The storage foundation MUST prevent UI, Playback, Provider, concrete torrent engines, virtual stream servers, piece schedulers, timeline overlays, and diagnostics consumers from bypassing approved BT task storage contracts for Step 18 runtime state.

#### Scenario: Derived consumer needs task state
- **WHEN** a derived consumer needs BT task identity, lifecycle, metadata, file selection, transfer, or event state
- **THEN** it reads through BT task storage or runtime projection contracts rather than direct database, filesystem, engine session, or module-owned cache access

### Requirement: Storage foundation SHALL persist virtual stream runtime state atomically
The storage foundation SHALL provide virtual stream storage contracts that persist stream identity, task/file binding, lifecycle state, buffered ranges, range failure metadata, latest stream event metadata, and updated timestamps as coherent Step 19 runtime transitions.

#### Scenario: Range buffering succeeds
- **WHEN** the virtual stream runtime records an available byte range
- **THEN** storage persists the buffered range and related event before the runtime reports the updated stream projection as replayable

### Requirement: Storage foundation SHALL support virtual stream restart reconstruction
The storage foundation SHALL expose enough persisted virtual stream state for runtime bootstrap code to distinguish active, closed, failed, missing-task, incomplete, and range-failed stream projections after restart.

#### Scenario: Runtime boots after process restart
- **WHEN** persisted virtual stream records exist
- **THEN** the runtime can rebuild stream descriptors, lifecycle projections, buffered ranges, and latest failure state from storage contracts without direct database, filesystem, or engine access

### Requirement: Storage foundation MUST enforce virtual stream storage boundaries
The storage foundation MUST prevent UI, Playback, Provider, concrete torrent engines, piece schedulers, timeline overlays, diagnostics consumers, and native player adapters from bypassing approved virtual stream storage or runtime projection contracts.

#### Scenario: Playback needs stream state
- **WHEN** playback needs a source for a BT-backed file
- **THEN** it reads through virtual stream runtime or playback handoff contracts rather than direct storage tables, filesystem paths, engine sessions, or module-owned caches

### Requirement: Storage foundation SHALL persist scheduler runtime state atomically
The storage foundation SHALL provide piece priority scheduler storage contracts that persist active profile selection, generated priority plans, ordered plan rules, latest application outcomes, failure metadata, and timestamps as coherent Step 20 runtime transitions.

#### Scenario: Priority plan is generated
- **WHEN** scheduler runtime generates a plan and its ordered rules
- **THEN** storage persists the profile, plan, and rules before the runtime reports the plan as replayable or publishes invalidation

### Requirement: Storage foundation SHALL support scheduler restart reconstruction
The storage foundation SHALL expose enough persisted scheduler state for runtime bootstrap code to reconstruct active profile state, latest plan projections, rule projections, latest application outcome, unavailable-input state, and rejected application state after restart.

#### Scenario: Runtime boots after process restart
- **WHEN** persisted scheduler records exist
- **THEN** the runtime can rebuild scheduler projections without querying a concrete torrent engine or native priority adapter

### Requirement: Storage foundation MUST enforce scheduler storage boundaries
The storage foundation MUST prevent UI, Playback, Provider, concrete torrent engines, virtual stream byte servers, timeline overlays, diagnostics consumers, and native player adapters from bypassing approved scheduler storage or runtime projection contracts.

#### Scenario: Derived consumer needs scheduler state
- **WHEN** a derived consumer needs profile, plan, rule, or application state
- **THEN** it reads through scheduler storage or runtime projection contracts rather than direct database, filesystem, engine session, or module-owned cache access

### Requirement: Atomic timeline overlay runtime state persistence
Local storage foundation SHALL support atomic persistence boundaries for timeline overlay runtime profiles, active profile mapping, ordered layer preferences, visibility, and latest snapshot metadata.

#### Scenario: Layer configuration persists atomically
- **WHEN** timeline overlay runtime accepts a layer visibility or ordering update
- **THEN** the complete updated layer configuration SHALL be persisted atomically before it is exposed to readers.

### Requirement: Timeline overlay restart reconstruction
Local storage foundation SHALL provide enough persisted overlay state for runtime bootstrap to distinguish configured, unconfigured, missing-profile, rejected-composition, and latest-snapshot states.

#### Scenario: Bootstrap restores latest snapshot metadata
- **WHEN** timeline overlay runtime starts for a stream with persisted snapshot metadata
- **THEN** it SHALL expose that metadata in restart projections without requiring UI state.

### Requirement: Timeline overlay storage boundary enforcement
Timeline overlay runtime SHALL access persisted overlay state through storage contracts and SHALL NOT bypass repository/storage boundaries or depend on concrete database implementations.

#### Scenario: Runtime uses storage abstraction
- **WHEN** runtime reads overlay profiles or layers
- **THEN** it SHALL use the timeline overlay storage contract rather than direct SQL, file, or platform storage APIs.

### Requirement: Storage foundation SHALL persist video enhancement runtime replay state
Local storage foundation SHALL provide enough video enhancement profile and pipeline state to distinguish disabled, evaluated, applied, rejected, degraded, active-profile, budget-pressure, and degradation-target runtime projections after restart.

#### Scenario: Enhancement runtime restarts after degradation
- **WHEN** video enhancement runtime starts with persisted active profile and latest degraded pipeline state
- **THEN** it can replay the active profile, state kind, budget pressure, and candidate degradation target without reading renderer, shader, native plugin, diagnostics, or UI state

### Requirement: Video enhancement runtime storage boundaries MUST remain contract-only
Video enhancement runtime SHALL access persisted enhancement profiles, active profile selection, and latest pipeline state through Storage contracts and SHALL NOT bypass repository/storage boundaries or depend on concrete database, shader file, renderer, native plugin, or platform storage APIs.

#### Scenario: Runtime persists applied profile
- **WHEN** the runtime accepts a supported enhancement profile application
- **THEN** it writes active profile and latest pipeline state through `EnhancementProfileStore` before exposing replayable state

### Requirement: Runtime SHALL rebuild advanced caption projection from store after restart
The system SHALL ensure `AdvancedCaptionRuntimeRestartProjection` reads active profile ID, latest renderer state kind, and dual subtitle selection from the caption store without requiring in-memory evaluation state.

#### Scenario: Restart projection from seeded store
- **WHEN** a runtime is created for a scope with stored active profile and applied renderer state
- **THEN** the restart projection reports the stored active profile ID and renderer state kind

### Requirement: Runtime SHALL persist caption rendering state through deterministic renderer
The system SHALL ensure `DeterministicAdvancedCaptionRenderer` persists profile, active profile, dual subtitle selection, and renderer state records to the caption store on every operation, enabling the runtime to project stored state on restart.

#### Scenario: Rendered feature persists state
- **WHEN** the runtime delegates a successful matrix danmaku render to the deterministic renderer
- **THEN** the caption store contains the latest renderer state record with `state: applied` and the rendered feature name

### Requirement: Fallback adapter runtime SHALL rebuild projection from store after restart
The system SHALL allow `FallbackAdapterRuntimeRestartProjection` to read stored active fallback configuration and strategy state from `FallbackAdapterStore` after a runtime restart, replaying the enabled state, selected candidate ID, and strategy state kind.

#### Scenario: Runtime replays stored fallback state after restart
- **WHEN** a new runtime is created via bootstrap after a previous runtime was disposed
- **THEN** the restart projection reads `activeConfiguration` and `latestStrategyState` from the store to restore fallback intent

### Requirement: Fallback adapter runtime SHALL persist fallback decisions on accepted requests
The system SHALL ensure that `selectFallback()`, `disable()`, `registerCandidate()`, and `reevaluateCapabilities()` operations persist their state and decision records to the fallback adapter store through the deterministic strategy before the runtime returns a typed projection.

#### Scenario: Runtime persists selection to store
- **WHEN** `selectFallback()` succeeds through the runtime
- **THEN** active configuration, selection history, and strategy state records are written to the fallback adapter store

### Requirement: Local storage foundation SHALL support RSS auto-download policy runtime evaluation replay
The local storage foundation SHALL allow the RSS auto-download policy runtime to persist and replay evaluation records, accepted candidates, rejected candidates, deduplication keys, and enqueue outcomes via the existing RssAutoDownloadPolicyStore contracts. The runtime SHALL read policyById, evaluationsForItem, acceptedCandidateById, and latestEnqueueOutcome from the store to build restart projections without introducing new storage types or migration steps.

#### Scenario: Runtime rebuilds projection from store after restart
- **WHEN** a new runtime instance is created for a scope that has previously stored policy, evaluation, candidate, and enqueue records
- **THEN** the runtime projection reads evaluation, candidate, and enqueue data from the existing policy store contracts without requiring additional storage schema changes

#### Scenario: Runtime persists evaluation decisions on accepted evaluations
- **WHEN** the runtime accepts an evaluation request
- **THEN** the runtime records the evaluation, stores accepted/rejected candidates, and records deduplication keys to the policy store, and the runtime projection reflects them on the next snapshot

### Requirement: Local storage foundation SHALL support online rule source runtime evaluation replay
The local storage foundation SHALL allow the online rule source runtime to persist and replay manifest validation results, evaluation snapshots, and unsupported operation records via the existing OnlineRuleRuntimeStore contracts. The runtime SHALL read manifestBySource, evaluationsForSource, and storeManifest from the store to build restart projections without introducing new storage types or migration steps.

#### Scenario: Runtime rebuilds projection from store after restart
- **WHEN** a new runtime instance is created for a scope that has previously stored manifest and evaluation records
- **THEN** the runtime projection reads manifest and evaluation data from the existing rule store contracts without requiring additional storage schema changes

#### Scenario: Runtime persists evaluation decisions on accepted evaluations
- **WHEN** the runtime accepts an evaluation request
- **THEN** the runtime records the evaluation snapshot to the rule store and the runtime projection reflects it on the next snapshot

### Requirement: Local storage foundation SHALL support WebView session backfill runtime replay
The local storage foundation SHALL allow the WebView session backfill runtime to persist and replay challenge requests, normalized session artifacts, backfill attempts, artifact revocation state, and capability state through existing `WebViewSessionBackfillStore` contracts.

#### Scenario: Runtime rebuilds projection from store after restart
- **WHEN** a new runtime instance is created for a provider scope with stored challenge, artifact, attempt, and capability records
- **THEN** the runtime projection reads those records from storage without requiring a concrete browser or WebView session

#### Scenario: Runtime records backfill attempt after retry preparation
- **WHEN** retry descriptor preparation succeeds or fails
- **THEN** the runtime records a `StoredWebViewSessionBackfillAttemptRecord` before returning the projection

