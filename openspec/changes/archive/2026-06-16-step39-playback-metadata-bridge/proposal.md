## Why

Step 39 connects the real metadata providers completed in Steps 36-38 to the
existing playback subtitle and danmaku runtimes without adding UI. The repo
already has provider clients, subtitle provider runtime, basic subtitle
parsing, basic danmaku rendering, and playback-state projection values, but app
composition has no stable Domain bridge that loads provider metadata into those
playback overlay runtimes.

This change adds that bridge as a focused Domain/runtime adapter. It does not
add playback-page widgets, subtitle selection UI, danmaku panel UI, advanced
caption rendering, player-native track mutation, provider login flows, or new
network clients.

## What Changes

- Add a Domain playback metadata bridge that can:
  - load a prepared provider subtitle into `BasicSubtitleRuntime`;
  - load Dandanplay comments into `BasicDanmakuRuntime`;
  - resolve subtitle and danmaku overlay projections from `PlayerClockSnapshot`;
  - expose immutable framework-neutral snapshots suitable for playback state
    composition.
- Preserve existing provider/runtime contracts: `SubtitleProviderRuntime`,
  `DandanplayCommentProvider`, `BasicSubtitleRuntime`, and
  `BasicDanmakuRuntime` remain independent and reusable.
- Add focused tests and smoke/checker coverage for subtitle handoff, danmaku
  handoff, failure normalization, disposal, and boundary isolation.
- Keep `lib/src/ui/**`, `lib/main.dart`, `windows/**`, provider HTTP clients,
  storage implementations, streaming engines, and native player bindings
  untouched.

## Impact

- Affected code is limited to Domain playback bridge implementation, tests,
  tools/checkers, docs, public exports, and OpenSpec specs.
- No live network is required; tests use deterministic provider/runtime inputs.
- UI models can later consume the bridge output through existing playback state
  and page-surface contracts without importing provider clients.
