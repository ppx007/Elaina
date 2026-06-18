# layered-architecture Specification

## Purpose
TBD - created by archiving change bootstrap-phase-0-foundation. Update Purpose after archive.
## Requirements
### Requirement: Eight-layer boundaries SHALL be explicit
The system SHALL define UI, Domain, Playback, Provider, Gateway, Storage, Streaming, and Network as distinct architectural layers with named responsibilities and explicit interfaces between layers.

#### Scenario: New project structure is initialized
- **WHEN** the first implementation slice scaffolds the project structure
- **THEN** each of the eight layers is represented as a distinct module or package boundary with documented responsibility

### Requirement: Cross-layer direct dependencies MUST be restricted
The system MUST prevent upper-layer features from directly depending on concrete implementations that belong behind layer boundaries, including direct UI dependencies on player engines, provider integrations, streaming engines, source-specific feeds, and storage internals.

#### Scenario: UI feature requests playback or provider data
- **WHEN** a UI-facing feature needs playback, metadata, or provider behavior
- **THEN** it depends on Domain or other approved abstractions rather than directly importing concrete MPV, VLC, Bangumi, Dandanplay, libtorrent, yuc.wiki, or storage implementations

### Requirement: Extension points SHALL be preserved at layer seams
The system SHALL preserve extension points for Adapter, Provider, Profile, and FeatureFlag-driven substitution at the boundaries named by the architecture plan.

#### Scenario: A future engine or provider is introduced
- **WHEN** a new player adapter or external provider is added in a later phase
- **THEN** the new implementation plugs into an existing extension seam without forcing cross-layer redesign

### Requirement: Phase 0 foundation runtime SHALL preserve layer isolation
The system SHALL provide an executable Phase 0 foundation runtime bootstrap that composes only the Step 1-4 foundation layers while preserving UI, Domain, Playback, Provider, Gateway, Storage, Streaming, and Network isolation.

#### Scenario: Foundation runtime is constructed
- **WHEN** the Phase 0 foundation runtime bootstrap is created for tests or early app-shell wiring
- **THEN** it exposes only foundation-safe Gateway, Storage, cache invalidation, and layer manifest surfaces without importing Flutter UI, playback adapters, provider implementations, streaming engines, or concrete network adapters

### Requirement: Layer boundary checks SHALL cover foundation bootstrap wiring
The system SHALL include executable checks that reject forbidden cross-layer dependencies in the Phase 0 foundation runtime bootstrap.

#### Scenario: Bootstrap imports a forbidden concrete adapter
- **WHEN** the foundation runtime bootstrap introduces direct dependencies on MPV, VLC, libtorrent, Flutter UI, concrete HTTP clients, DNS/proxy clients, WebView controllers, or source-specific scrapers
- **THEN** the boundary checker fails before the bootstrap can be treated as a valid foundation implementation

### Requirement: Phase 1 player core runtime SHALL preserve layer isolation
The system SHALL provide an executable Phase 1 player core runtime bootstrap that composes only Playback and approved Domain-facing playback surfaces while preserving UI, Foundation, Provider, Gateway, Storage, Streaming, and Network isolation.

#### Scenario: Player core runtime is constructed
- **WHEN** the Phase 1 player core runtime bootstrap is created for tests or early app-shell wiring
- **THEN** it does not import Flutter UI, provider implementations, storage implementations, streaming engines, network clients, concrete MPV/libmpv/media-kit bindings, VLC, BT engines, online rule runtimes, or diagnostics UI

### Requirement: Layer boundary checks SHALL cover player core runtime wiring
The system SHALL include executable checks that reject forbidden cross-layer dependencies in Phase 1 player core runtime and bootstrap files.

#### Scenario: Player core runtime imports a forbidden system
- **WHEN** player core runtime introduces direct dependencies on Flutter widgets, concrete provider integrations, storage internals, BT streaming, network clients, VLC fallback, native player bindings, diagnostics UI, or online rule parsing
- **THEN** the boundary checker fails before the runtime can be treated as a valid Phase 1 implementation

### Requirement: Basic subtitle runtime SHALL preserve layer isolation
The basic subtitle runtime SHALL keep parser, scanner, offset, cue-resolution, and runtime composition dependencies within allowed Playback and Domain-facing contract boundaries and MUST NOT introduce dependencies from Playback or Domain into UI, concrete Provider implementations, Gateway implementations, Storage implementations, Streaming implementations, Network implementations, diagnostics UI, or native player bindings.

#### Scenario: Subtitle runtime imports are checked
- **WHEN** automation scans the basic subtitle runtime, subtitle parser implementations, scanner implementations, and Domain-facing subtitle state files
- **THEN** the scan finds no imports of Flutter widgets, MPV, VLC, libmpv, media-kit, platform channels, concrete provider implementations, gateway internals, storage internals, streaming engines, network clients, diagnostics UI, BT engines, Bangumi, Dandanplay, RSS runtime, online rule runtime, or advanced caption rendering internals

### Requirement: Advanced caption rendering SHALL remain downstream of basic subtitle runtime
Advanced caption rendering SHALL depend on basic subtitle cue/source contracts only through explicit extension boundaries, and the basic subtitle runtime MUST NOT import advanced caption rendering implementation details.

#### Scenario: Advanced caption work is absent
- **WHEN** the basic subtitle runtime is validated before advanced caption rendering implementation
- **THEN** parser, scanner, offset, active-cue, and subtitle state validation passes without advanced caption rendering code

### Requirement: Concrete implementation slices SHALL preserve UI ownership boundaries
Concrete runtime implementation changes SHALL keep UI implementation work
separate when ownership is assigned to an external UI track. Core implementation
changes MAY expose stable contracts and release packaging tools for UI/app-shell
consumption, but MUST NOT add app shells, routes, pages, widgets, file picker
UX, or video-surface widgets when the change scope excludes UI.

#### Scenario: Player core release packaging is implemented
- **WHEN** bundled MPV packaging support is added as a core implementation slice
- **THEN** `lib/src/ui/**` and `lib/main.dart` remain untouched while Playback
  and release tooling provide the integration surface for future UI work

### Requirement: UI-owned app shell SHALL consume playback composition through contracts
Core runtime changes SHALL expose stable Domain/Playback contracts for the app
composition root when UI ownership is assigned to an external implementation
track, but MUST NOT implement app shell, routes, pages, file picker UX, video
surfaces, or Flutter widgets.

#### Scenario: External UI model wires local playback
- **WHEN** the external UI app shell needs local file playback
- **THEN** it may create the Playback-owned media_kit/libmpv composition
  descriptor and pass it to the Domain player-core bootstrap, but it MUST NOT
  import `package:media_kit`, concrete libmpv types, VLC, provider clients,
  storage internals, streaming engines, or network implementations directly

#### Scenario: Boundary checker scans UI entry points
- **WHEN** player-core validation scans `lib/src/ui/**` and `lib/main.dart`
- **THEN** concrete player package imports and concrete native player
  dependencies are rejected from UI-owned files

### Requirement: Step 34 UI integration contract SHALL remain non-UI implementation work
Step 34 UI integration contract work SHALL provide stable source, lifecycle,
dispose, and error-handling contracts for the external UI model without adding
Flutter app shell, routes, pages, widgets, file picker UX, video surfaces, or
Windows runner implementation.

#### Scenario: Integration contract is implemented
- **WHEN** Step 34 integration guidance is added
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  while docs, tests, checkers, and OpenSpec specs define the external UI
  model's playback integration boundary

### Requirement: Step 35 smoke gate SHALL remain outside UI implementation ownership
Step 35 smoke gate work SHALL provide non-UI playback and packaged release
verification tooling while leaving Flutter app shell, routes, pages, widgets,
file picker UX, video surfaces, and Windows runner implementation to the
external UI track.

#### Scenario: Smoke gate tooling is added
- **WHEN** Step 35 smoke gate tooling and docs are added
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  and validation continues to enforce concrete player dependency boundaries

### Requirement: Step 36 Bangumi API client SHALL preserve UI ownership boundaries
Step 36 concrete Bangumi API client work SHALL provide Provider-layer
implementation, runtime injection, tests, checkers, and integration notes
without adding or modifying Flutter app shell, routes, pages, widgets, login
screens, detail pages, file picker UX, playback surfaces, Windows runner files,
or UI state composition.

#### Scenario: Concrete Bangumi client is implemented
- **WHEN** Step 36 adds real Bangumi API dispatch support
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  and UI-owned code may consume only Domain/Provider contracts rather than
  concrete Bangumi transport or API payload types

### Requirement: Step 37 Dandanplay API client SHALL preserve UI ownership boundaries
Step 37 concrete Dandanplay API client work SHALL provide Provider-layer
implementation, runtime injection, tests, checkers, and integration notes
without adding or modifying Flutter app shell, routes, pages, widgets, login
screens, danmaku panels, playback overlays, Windows runner files, or UI state
composition.

#### Scenario: Concrete Dandanplay client is implemented
- **WHEN** Step 37 adds real Dandanplay API dispatch support
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  and UI-owned code may consume only Domain/Provider contracts rather than
  concrete Dandanplay transport or API payload types

### Requirement: Step 38 OpenSubtitles API client SHALL preserve UI ownership boundaries
Step 38 concrete OpenSubtitles provider work SHALL provide Provider-layer
implementation, tests, checkers, and integration notes without adding or
modifying Flutter app shell, routes, pages, widgets, subtitle search panels,
playback overlays, Windows runner files, or UI state composition.

#### Scenario: Concrete OpenSubtitles provider is implemented
- **WHEN** Step 38 adds real subtitle provider dispatch support
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  and UI-owned code may consume only Domain/Provider contracts rather than
  concrete OpenSubtitles transport or API payload types

### Requirement: Step 39 playback metadata bridge SHALL preserve UI ownership boundaries
Step 39 playback metadata bridge work SHALL provide Domain/runtime
composition, tests, checkers, and integration notes without adding or modifying
Flutter app shell, routes, pages, widgets, subtitle panels, danmaku panels,
playback overlays, Windows runner files, or UI state composition.

#### Scenario: Metadata bridge is implemented
- **WHEN** Step 39 connects subtitle and danmaku provider outputs to playback
  runtime projections
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  and UI-owned code may consume only Domain/Playback contracts rather than
  concrete provider clients or playback metadata bridge internals

### Requirement: Step 40 ACG smoke gate SHALL preserve UI ownership boundaries
Step 40 ACG smoke gate work SHALL provide Domain/runtime composition, tests,
checkers, and integration notes without adding or modifying Flutter app shell,
routes, pages, widgets, login screens, metadata panels, subtitle panels,
danmaku panels, playback overlays, Windows runner files, or UI state
composition.

#### Scenario: ACG smoke gate is implemented
- **WHEN** Step 40 validates Bangumi, Dandanplay, subtitle provider, and
  playback metadata bridge composition
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  and UI-owned code may consume only Domain/Playback contracts rather than
  concrete provider clients or smoke-gate internals

### Requirement: SQLite implementation details MUST stay inside Foundation/Storage
Concrete SQLite imports, handles, SQL statements, schema bootstrap code, and row-mapping logic MUST remain inside Foundation/Storage implementation files, tests, and non-UI smoke tools.

#### Scenario: A non-storage layer needs persisted data
- **WHEN** UI, Domain, Playback, Provider, Streaming, or Network code needs persisted data
- **THEN** it consumes existing storage contracts or runtime projections rather than importing SQLite packages, opening database handles, or issuing SQL directly

### Requirement: Step 42 media-library implementation SHALL preserve layer boundaries
Step 42 concrete media-library runtime work SHALL keep filesystem scanning and
storage-backed composition behind Domain/Foundation contracts while preserving
the external UI ownership boundary.

#### Scenario: Boundary checks scan Step 42 files
- **WHEN** media-library runtime validation scans Step 42 implementation,
  tests, tools, and docs
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  SQLite and SQL details are found only in Foundation/Storage implementation
  and tests/tools, and Domain media runtime surfaces do not import provider
  clients, streaming engines, network clients, MPV/VLC bindings, or Flutter UI

### Requirement: Step 43 video-detail implementation SHALL preserve layer boundaries
Step 43 concrete video-detail runtime work SHALL keep storage-backed detail
composition behind Domain/Foundation contracts while preserving the external
UI ownership boundary.

#### Scenario: Boundary checks scan Step 43 files
- **WHEN** video-detail runtime validation scans Step 43 implementation, tests,
  tools, and docs
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  SQLite and SQL details stay inside Foundation/Storage implementation and
  tests/tools, and Domain detail runtime surfaces do not import concrete
  provider transports, ProviderGateway runtime internals, streaming engines,
  network clients, MPV/VLC bindings, Flutter widgets, RSS automation, or
  diagnostics implementations

### Requirement: Playback history integration SHALL preserve UI and concrete-player boundaries
Playback history integration SHALL live in Domain media/runtime composition and
consume Domain playback state contracts without depending on Flutter UI or
concrete native player bindings.

#### Scenario: History integration is validated
- **WHEN** boundary checkers scan Step 44 implementation files
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  media_kit/libmpv/VLC imports stay out of Domain media files, and SQLite/SQL
  details remain behind storage adapters rather than leaking into playback
  history integration logic

### Requirement: Step 45 library smoke gate SHALL preserve UI ownership boundaries
Step 45 library smoke gate work SHALL provide non-UI runtime composition,
tests, checker tooling, and integration notes without adding or modifying
Flutter app shell, routes, pages, widgets, file picker UX, playback pages,
Windows runner files, or UI state composition.

#### Scenario: Library smoke gate is implemented
- **WHEN** Step 45 validates scan, import, detail, playback handoff, playback
  history, binding, and continue-watching replay
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  and UI-owned code may consume only Domain/runtime contracts rather than
  concrete smoke-gate internals, SQLite SQL, provider transports, native player
  bindings, streaming engines, or network implementations

### Requirement: Step 46 RSS fetch/parser SHALL preserve UI ownership boundaries
Step 46 concrete RSS fetch/parser work SHALL provide Provider-layer feed
adapters, tests, checker tooling, and integration notes without adding or
modifying Flutter app shell, routes, RSS pages, widgets, Windows runner files,
or UI state composition.

#### Scenario: RSS fetch/parser is implemented
- **WHEN** Step 46 adds concrete HTTP feed fetching and RSS/Atom parsing
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  `dart:io` and XML parser imports stay out of Domain RSS runtime files, and
  UI-owned code may consume only Domain/runtime contracts rather than concrete
  transport/parser internals

### Requirement: Step 47 seasonal feed flow SHALL preserve UI and provider boundaries
Step 47 seasonal feed flow work SHALL compose RSS and seasonal Domain/runtime
contracts without adding Flutter UI ownership or leaking concrete feed transport
and parser packages into seasonal Domain files.

#### Scenario: Seasonal feed flow is implemented
- **WHEN** Step 47 adds the seasonal feed flow runtime, tests, tools, and docs
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  concrete HTTP/XML details remain outside Domain seasonal files, and UI-owned
  code may consume only Domain/runtime contracts and projections

### Requirement: Step 48 online rule evaluator SHALL preserve layer boundaries
Step 48 online rule evaluator work SHALL provide Provider-layer supplied
document validation and evaluation, tests, checker tooling, and integration
notes without adding or modifying Flutter app shell, routes, pages, widgets,
WebView screens, Windows runner files, network fetch implementations, BT
streaming, RSS auto-download, diagnostics actions, or UI state composition.

#### Scenario: Online rule evaluator is implemented
- **WHEN** Step 48 adds concrete CSS, XPath, and regex supplied-document
  evaluation
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  executable rule operations remain rejected, and UI-owned code may consume only
  Provider/runtime contracts and projections rather than parser internals,
  crawler implementations, WebView handles, network clients, or source-specific
  scraper details

### Requirement: Step 49 online rule test harness SHALL preserve layer boundaries
Step 49 online rule test harness work SHALL provide Provider-layer validation
and supplied-document test reporting, tests, checker tooling, and integration
notes without adding or modifying Flutter app shell, routes, pages, widgets,
WebView screens, Windows runner files, network fetch implementations, BT
streaming, RSS auto-download, diagnostics actions, or UI state composition.

#### Scenario: Online rule test harness is implemented
- **WHEN** Step 49 adds the rule-source test harness
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  executable rule operations remain rejected by existing validation, and
  UI-owned code may consume only Provider/runtime contracts and harness reports
  rather than parser internals, crawler implementations, WebView handles,
  network clients, or source-specific scraper details

### Requirement: Step 50 automation smoke gate SHALL preserve layer boundaries
Step 50 automation smoke gate work SHALL provide non-UI composition tests,
checker tooling, and integration notes for the RSS refresh, seasonal feed flow,
and online rule test harness path without adding or modifying Flutter app
shell, routes, pages, widgets, WebView screens, Windows runner files, live
network source fetching, native player bindings, RSS auto-download handoff, BT
streaming, diagnostics actions, or UI state composition.

#### Scenario: Automation smoke gate is implemented
- **WHEN** Step 50 validates RSS refresh, seasonal catalog projection,
  Bangumi match queue projection, and supplied-document online rule test
  reporting
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  RSS concrete transport/parser details stay out of seasonal Domain files, and
  UI-owned code may consume only existing Domain/Provider runtime contracts
  rather than smoke-gate internals, WebView handles, crawler implementations,
  source-specific scrapers, BT engines, diagnostics actions, or native player
  dependencies

### Requirement: Layered architecture SHALL isolate concrete BT engine packages
Concrete BT engine packages SHALL be imported only by approved Streaming-layer
adapter implementation files and tests. UI, Domain, Playback, Provider,
Gateway, Storage, Network, diagnostics, and neutral Streaming contracts SHALL
consume BT behavior only through declared Celesteria contracts, including the
neutral BT task runtime composition contract.

#### Scenario: Concrete BT package import is scanned
- **WHEN** boundary validation scans Dart source files
- **THEN** `package:libtorrent_flutter/` imports are accepted only in the
  approved concrete BT adapter file and rejected everywhere else in `lib/src`

### Requirement: Layered architecture SHALL isolate concrete virtual byte sources
Concrete virtual byte-source implementations SHALL be imported only by
approved Streaming-layer adapter implementation files and tests. UI, Domain,
Playback, Provider, Gateway, Storage, Network, diagnostics, and neutral
Streaming runtime contracts SHALL consume virtual byte serving only through
declared Celesteria virtual stream contracts.

#### Scenario: Concrete byte source import is scanned
- **WHEN** boundary validation scans Dart source files
- **THEN** `dart:io` file reads and `RandomAccessFile` usage for virtual
  byte serving are accepted only in the approved concrete byte source file and
  rejected from neutral runtime files

### Requirement: Layered architecture SHALL isolate concrete piece-priority appliers
Concrete piece-priority plan appliers SHALL be implemented only inside
approved Streaming-layer adapter implementation files and tests. UI, Domain,
Playback, Provider, Gateway, Storage, Network, diagnostics, and neutral
Streaming scheduler runtime contracts SHALL consume priority application only
through `PiecePriorityPlanApplier` and normalized scheduler outcomes.

#### Scenario: Concrete priority applier import is scanned
- **WHEN** boundary validation scans Dart source files
- **THEN** concrete torrent package imports and backend priority APIs are
  accepted only in approved Streaming adapter implementation files and tests,
  while neutral scheduler runtime files remain adapter-neutral

### Requirement: Step 55 BT streaming smoke gate SHALL preserve layer boundaries
Step 55 BT streaming smoke gate work SHALL provide non-UI composition tests,
checker tooling, and integration notes for the BT task, virtual stream, byte
serving, and priority application path without adding or modifying Flutter app
shell, routes, pages, widgets, file picker UX, playback pages, Windows runner
files, native player bindings, HTTP/range servers, network policy
implementations, diagnostics actions, RSS automation, or UI state composition.

#### Scenario: BT streaming smoke gate runs without UI ownership
- **WHEN** Step 55 validates the BT streaming path
- **THEN** it composes only Streaming-layer contracts, concrete Streaming
  adapters, storage contracts, and smoke tooling, while leaving `lib/src/ui/**`,
  `lib/main.dart`, and `windows/**` untouched

### Requirement: Step 56 SHALL keep enhancement binding out of UI ownership
Step 56 SHALL implement concrete enhancement application inside Playback-owned
binding code and SHALL NOT add or modify Flutter UI, app shell, route, settings
page, playback overlay, file picker, video surface, `lib/main.dart`, or
`windows/**` files.

#### Scenario: Step 56 files are reviewed
- **WHEN** the Step 56 change is validated
- **THEN** concrete enhancement implementation files are confined to Playback
  source, tests, tools, docs, and OpenSpec artifacts, with no UI/app-shell
  ownership changes

### Requirement: Step 57 SHALL keep concrete subtitle rendering out of UI ownership
Step 57 SHALL implement concrete subtitle application inside Playback-owned
binding code and SHALL NOT add or modify Flutter UI, app shell, route, settings
page, playback overlay, subtitle overlay, file picker, video surface,
`lib/main.dart`, or `windows/**` files.

#### Scenario: Step 57 files are reviewed
- **WHEN** the Step 57 change is validated
- **THEN** concrete subtitle renderer implementation files are confined to
  Playback source, tests, tools, docs, and OpenSpec artifacts, with no
  UI/app-shell ownership changes

### Requirement: Step 58 SHALL keep VLC fallback implementation out of UI ownership
Step 58 SHALL implement VLC fallback adapter core behavior inside
Playback-owned code and SHALL NOT add or modify Flutter UI, app shell, route,
settings page, fallback status display, playback overlay, file picker, video
surface, `lib/main.dart`, or `windows/**` files.

#### Scenario: Step 58 files are reviewed
- **WHEN** the Step 58 change is validated
- **THEN** concrete VLC fallback implementation files are confined to Playback
  source, tests, tools, docs, and OpenSpec artifacts, with no UI/app-shell or
  runner ownership changes

