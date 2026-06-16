## 1. OpenSpec

- [x] 1.1 Create change `step31-concrete-player-core-binding`.
- [x] 1.2 Add spec deltas for concrete player binding, runtime wiring, and UI exclusion.
- [x] 1.3 Run `openspec.cmd instructions apply --change "step31-concrete-player-core-binding" --json`.

## 2. Concrete Binding

- [x] 2.1 Add media_kit/libmpv package dependencies.
- [x] 2.2 Implement a Playback-layer concrete `MpvAdapterBinding` for local file load, play, pause, seek, stop, and dispose.
- [x] 2.3 Preserve normalized unsupported behavior for HTTP/HLS and track operations unless implemented and tested.
- [x] 2.4 Keep media_kit/libmpv types out of Domain, UI, Provider, Storage, Streaming, and Network code.

## 3. Runtime Wiring

- [x] 3.1 Add concrete player-core bootstrap/factory wiring through `MpvPlayerAdapterFacade.bound(...)`.
- [x] 3.2 Expose only verified concrete capabilities to `PlayerCoreRuntime`.
- [x] 3.3 Preserve existing deterministic and unsupported player-core paths.

## 4. Tests And Checkers

- [x] 4.1 Add concrete binding tests for command mapping, source gating, and lifecycle failures.
- [x] 4.2 Update player-core boundary checker to allow concrete player imports only in approved Playback binding/test files.
- [x] 4.3 Verify no changes are made under `lib/src/ui/**` or `lib/main.dart`.

## 5. Validation And Archive

- [x] 5.1 Run focused player-core tests and checker.
- [x] 5.2 Run `openspec.cmd validate "step31-concrete-player-core-binding" --strict`.
- [x] 5.3 Run baseline validation gates.
- [x] 5.4 Archive the OpenSpec change.
- [x] 5.5 Re-run `openspec.cmd validate --all` and report git status.

## Verification Notes

- A non-UI smoke tool was added at `tools/media_kit_mpv_binding_smoke.dart`.
- Direct Dart CLI smoke generated a temporary MP4 and reached the concrete
  binding, but media_kit initialization failed because the current environment
  cannot find `libmpv-2.dll` on `%PATH%`. This records the native smoke blocker
  explicitly instead of treating deterministic/fake backend tests as proof of a
  working native player process.
