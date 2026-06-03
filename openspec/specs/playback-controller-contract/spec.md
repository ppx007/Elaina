# playback-controller-contract Specification

## Purpose
TBD - created by archiving change playback-controller-contract. Update Purpose after archive.
## Requirements
### Requirement: Playback controller contract SHALL dispatch page intents through controller commands
The playback controller contract SHALL expose a framework-neutral path for converting `PlaybackPageIntent` values into controller command results without requiring Flutter, native player bindings, provider systems, gateway, storage, streaming, or network layers.

#### Scenario: Play intent is dispatched through the controller
- **WHEN** a playback page play intent is handled by the controller boundary
- **THEN** the result is reported through the playback page intent result contract without importing Flutter, MPV, VLC, libmpv, media-kit, provider internals, streaming internals, gateway, storage, network, or native bindings

### Requirement: Playback controller contract SHALL expose observable state updates
The playback controller contract SHALL expose the current `PlaybackStateSnapshot` and notify observers when deterministic mock playback actions change lifecycle, timeline, buffering, track, source, or failure state.

#### Scenario: Seek updates observable timeline state
- **WHEN** a seek intent is accepted by the controller boundary
- **THEN** observers can receive a playback state snapshot with the updated timeline position without depending on Flutter state managers, native callbacks, provider metadata, storage records, streaming engines, gateway clients, or network clients

### Requirement: Playback controller contract SHALL remain mock-first
The first controller-backed playback loop SHALL use deterministic mock behavior and MUST NOT load real media, open native video surfaces, call platform channels, resolve providers, read storage, contact gateways, start streaming engines, or perform network requests.

#### Scenario: Controller loop is tested without native playback
- **WHEN** controller dispatch and observation tests run
- **THEN** they complete without requiring MPV, VLC, libmpv, media-kit, platform channels, provider systems, gateway, storage, streaming, network, diagnostics, danmaku, Anime4K, or production app state

### Requirement: Playback controller contract SHALL preserve layer isolation
The controller contract SHALL keep Domain and Playback code framework-neutral and MUST NOT cause non-UI layers to import Flutter shell files, Flutter packages, `dart:ui`, provider implementations, gateway implementations, storage implementations, streaming implementations, or network implementations.

#### Scenario: Controller imports are checked
- **WHEN** automation scans Domain, Playback, Provider, Gateway, Storage, Streaming, and Network Dart files
- **THEN** no import points into Flutter UI shell code, Flutter packages, `dart:ui`, provider implementations, gateway implementations, storage implementations, streaming implementations, or network implementations are present from those layers

### Requirement: Playback controller contract SHALL reuse existing surface, intent, and state contracts
The controller-backed loop SHALL reuse `PlaybackPageSurfaceDescriptor`, `PlaybackPageIntent`, `PlaybackPageIntentResult`, and `PlaybackStateSnapshot` rather than defining parallel UI-local or adapter-local models for the same concepts.

#### Scenario: Shell consumes controller-backed contracts
- **WHEN** the Flutter shell is driven by controller-backed mock playback
- **THEN** rendered state, visible controls, panel entry points, and intent results come from existing playback page and playback state contracts

