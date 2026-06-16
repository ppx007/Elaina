## 1. OpenSpec

- [x] 1.1 Create change `step39-playback-metadata-bridge`.
- [x] 1.2 Add spec deltas for playback metadata bridge and UI ownership boundaries.
- [x] 1.3 Run `openspec.cmd instructions apply --change "step39-playback-metadata-bridge" --json`.

## 2. Bridge Implementation

- [x] 2.1 Add a Domain playback metadata bridge that composes existing subtitle and danmaku runtimes.
- [x] 2.2 Load provider subtitle handoff results into `BasicSubtitleRuntime` without provider-specific parser branches.
- [x] 2.3 Load Dandanplay comments into `BasicDanmakuRuntime` using existing deterministic conversion.
- [x] 2.4 Resolve framework-neutral playback subtitle/danmaku snapshots from `PlayerClockSnapshot`.
- [x] 2.5 Normalize failures and disposed behavior without throwing raw provider/runtime errors across the bridge.

## 3. Tests And Checkers

- [x] 3.1 Add focused bridge tests for subtitle load, danmaku load, projection, failure, and disposal.
- [x] 3.2 Extend runtime smoke/checkers to require the bridge and forbid UI/provider-client/native-player leaks.
- [x] 3.3 Add integration notes for UI/app composition without editing UI files.

## 4. Validation And Archive

- [x] 4.1 Run focused playback metadata bridge tests and related checkers.
- [x] 4.2 Run `openspec.cmd validate "step39-playback-metadata-bridge" --strict`.
- [x] 4.3 Run baseline validation gates.
- [x] 4.4 Archive the OpenSpec change.
- [x] 4.5 Re-run `openspec.cmd validate --all` and report git status.
