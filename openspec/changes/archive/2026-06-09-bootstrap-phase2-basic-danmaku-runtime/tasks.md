## 1. Playback Danmaku Runtime

- [x] 1.1 Add deterministic `BasicDanmakuRenderer` implementation that groups eligible scrolling, top, and bottom comments into immutable render lanes.
- [x] 1.2 Add basic danmaku runtime state, lifecycle, failure kinds, immutable snapshots, comment loading, frame resolution, and disposed-state behavior under `lib/src/playback/danmaku/`.
- [x] 1.3 Apply `DanmakuFilter` before `DanmakuDensityPolicy`, preserve deterministic ordering, and enforce max-comments-per-window behavior in runtime frames.
- [x] 1.4 Ensure Playback-layer danmaku runtime files do not import Provider, Gateway, Storage, Network, UI, advanced caption, MPV/VLC, native player, RSS, BT, or online-rule modules.

## 2. Domain and Surface Projection

- [x] 2.1 Add Domain-facing basic danmaku state projection from runtime snapshots to immutable playback state values.
- [x] 2.2 Add Dandanplay comment normalization helpers that map provider comment mode, timestamp, text, and color into `DanmakuComment` values without coupling Playback to provider runtime implementations.
- [x] 2.3 Extend playback state snapshots with optional basic danmaku overlay data while preserving framework-neutral and provider-neutral contracts.
- [x] 2.4 Extend playback page surface descriptors with basic danmaku overlay descriptors for scrolling, top, and bottom lanes without adding Flutter widget, Canvas, native-renderer, or provider dependencies.
- [x] 2.5 Export only safe basic danmaku runtime/state/bridge surfaces through `lib/elaina.dart`.

## 3. Tests and Validation

- [x] 3.1 Add focused danmaku runtime tests for clock eligibility, scrolling/top/bottom lane grouping, filtering, density limits, deterministic ordering, immutable snapshots, and disposed behavior.
- [x] 3.2 Add Domain and playback-page surface tests proving danmaku overlay state projects into framework-neutral descriptors and existing subtitle/playback state remains intact.
- [x] 3.3 Add Dandanplay-to-Danmaku bridge tests proving provider comment normalization does not make Playback import provider runtime or gateway implementations.
- [x] 3.4 Add `tools/danmaku_runtime_check.dart` smoke validation covering runtime frame resolution, Domain projection, Dandanplay normalization, and existing Dandanplay/subtitle/player runtime checks.
- [x] 3.5 Add `tools/check_danmaku_runtime.ps1` boundary validation that rejects Flutter UI, Canvas/CustomPainter, Matrix4/advanced caption coupling, ProviderGateway, Dandanplay runtime imports in Playback files, Storage, Network, RSS, BT, online-rule, MPV/VLC, and native player dependencies.
- [x] 3.6 Run `openspec validate "bootstrap-phase2-basic-danmaku-runtime" --strict`, `openspec validate --all`, `dart analyze`, focused danmaku tests, danmaku checker scripts, and existing Dandanplay/subtitle/player runtime smoke checks.
