## 1. UI Intent Contract

- [x] 1.1 Add plain Dart playback page intent identifiers, payload types, and result types in the UI playback contract layer.
- [x] 1.2 Add intent dispatch logic that resolves the active playback page surface descriptor before calling Domain playback commands.
- [x] 1.3 Return deterministic executed, ignored, and unsupported intent results for transport, seek, panel, and track-selection actions.

## 2. Domain Boundary Integration

- [x] 2.1 Wire play, pause or play-pause, seek, stop, and track-selection intents through `PlaybackController` without importing concrete Playback implementations.
- [x] 2.2 Ensure track-selection intents use Domain-facing track identifiers from the existing track-management contract.
- [x] 2.3 Keep secondary panel intents UI-owned and avoid adding provider, streaming, gateway, storage, network, native player, or Flutter dependencies.

## 3. Verification

- [x] 3.1 Extend the Dart runtime checker to cover supported, ignored, and unsupported playback page intents.
- [x] 3.2 Extend or reuse automation checks to verify Domain and Playback layers do not import UI intent contract types.
- [x] 3.3 Run `dart analyze`, `powershell -ExecutionPolicy Bypass -File "tools\check_automation_extension_core.ps1"`, and `openspec validate --all`.
