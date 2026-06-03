## 1. Playback State Values

- [x] 1.1 Add immutable playback lifecycle status, timeline, buffering, and snapshot value types. Layers: Domain, Playback contract.
- [x] 1.2 Represent active audio and subtitle tracks with Domain-facing track identifiers only. Layers: Domain, Playback contract.
- [x] 1.3 Export the playback state contract through the public Dart package barrel if needed for validation. Layers: package API.

## 2. State Observation Boundary

- [x] 2.1 Add a minimal implementation-neutral playback state observation interface. Layers: Domain, Playback contract.
- [x] 2.2 Keep observation free of Flutter, package-specific state managers, native callbacks, adapters, providers, streaming, storage, gateway, and network dependencies. Layers: Domain, Playback contract, Tooling.

## 3. Verification

- [x] 3.1 Extend Dart runtime checks for immutable state snapshots, lifecycle/timeline separation, buffering data, and active track identifiers. Layers: Tooling.
- [x] 3.2 Extend or reuse boundary checks to verify playback state contracts do not import later-phase systems or Flutter/native playback bindings. Layers: Tooling.
- [x] 3.3 Run `dart analyze`, `powershell -ExecutionPolicy Bypass -File "tools\check_automation_extension_core.ps1"`, and `openspec validate --all`. Layers: Tooling.
