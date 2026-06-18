# Frontend Handoff

This document is the entry point for the external frontend/UI implementation
track. The current repository is ready for frontend development against stable
core contracts, but it is not a complete end-user app yet.

## Current Readiness

The core/runtime baseline is complete through Step 60:

- OpenSpec is the active workflow authority.
- Core runtime, provider, storage, playback, streaming, diagnostics, and smoke
  gates are implemented and archived through the full feature gate.
- Public contracts are exported from `lib/celesteria.dart`.
- The existing Flutter playback shell is a contract/mock harness, not the final
  application shell.
- There is no `lib/main.dart` yet. Creating the app entry point is frontend
  ownership.

The current state is suitable for frontend implementation to begin. It is not
yet suitable for customer unzip-and-run release until the UI runner, video
surface, file-open flow, packaging output, and strict native smoke are joined.

## Ownership Split

Frontend owns:

- `lib/main.dart`
- app shell and dependency composition root
- navigation and routing
- home, media library, detail, playback, downloads, RSS, settings, and
  diagnostics pages
- Flutter widgets, layout, visual design, and UI state composition
- file picker UX
- video surface widget and platform rendering integration
- manual UI smoke for packaged builds

Core/runtime already owns:

- Domain playback contracts and controller surfaces
- player runtime composition contracts
- local file playback binding and capability matrix
- provider clients and provider gateway boundaries
- storage/runtime contracts and deterministic test harnesses
- media library, video detail, RSS, online rule, BT streaming, diagnostics, and
  advanced playback runtime surfaces
- OpenSpec, checker scripts, and non-UI smoke gates

## Hard Boundaries

Frontend code must consume Domain/UI-facing contracts. It must not directly
depend on concrete backend implementations.

Do not import or branch on:

- `package:media_kit`
- libmpv handles or media-kit player objects
- VLC concrete backend objects
- libtorrent concrete engine objects
- Bangumi or Dandanplay API client internals
- OpenSubtitles API client internals
- SQLite/drift/sqlite3 storage internals
- WebView/network implementation details
- smoke tools under `tools/`

Use capability data instead of backend knowledge. If a capability is not
declared as supported, the UI must hide or disable the related control instead
of calling a concrete adapter directly.

## Primary Entry Points

Read these first:

- `lib/celesteria.dart`
- `docs/player-runtime-composition.md`
- `docs/player-capability-gate.md`
- `docs/player-ui-integration-contract.md`
- `docs/player-smoke-gate.md`
- `docs/full-feature-gate.md`

Playback contracts:

- `PlayerCoreBootstrap`
- `PlayerRuntimeCompositionContract`
- `mediaKitLocalFilePlayerRuntimeComposition(...)`
- `PlaybackControllerContract`
- `PlaybackStateSnapshot`
- `PlaybackCapabilityMatrix`
- `PlaybackPageContract`
- `PlaybackPageSurfaceDescriptor`
- `PlaybackPageIntent`
- `LocalPlaybackSourceHandoff`

Media/detail contracts:

- `MediaLibraryRuntime`
- `LocalFileMediaLibraryScanner`
- `VideoDetailController`
- `VideoDetailPageContract`
- `PlaybackHistoryRecorder`

Provider/metadata contracts:

- `AcgExperienceRuntime`
- `BangumiRuntime`
- `DandanplayRuntime`
- `SubtitleProviderRuntime`
- `PlaybackMetadataBridge`

Automation/streaming/diagnostics contracts:

- `RssEngineRuntime`
- `SeasonalFeedFlowRuntime`
- `OnlineRuleSourceRuntime`
- `BtTaskCoreRuntime`
- `VirtualMediaStreamRuntime`
- `PiecePrioritySchedulerRuntime`
- `TimelineOverlayRuntime`
- `DiagnosticsCenterRuntime`

## First UI Milestone

The first frontend milestone should be a desktop app shell that can open and
control local playback without leaking concrete player dependencies into UI
code.

Minimum scope:

- create `lib/main.dart`
- create the root Flutter app and navigation shell
- create the composition root for foundation and player runtime objects
- create a playback page that consumes `PlaybackPageContract`
- add file picker UX and convert selected files through
  `LocalPlaybackSourceHandoff`
- render a video surface through the chosen frontend/platform approach
- show only controls exposed by `PlaybackPageSurfaceDescriptor`
- dispose long-lived runtime objects from the app composition owner

Do not start with marketing pages or decorative shells. The first screen should
make the app usable for local playback.

## Playback Composition Sketch

The app composition root should create long-lived runtime objects and pass only
contract-facing values into widgets:

```dart
final PlayerRuntimeCompositionContract composition =
    mediaKitLocalFilePlayerRuntimeComposition(libmpvPath: optionalLibMpvPath);

final PlayerCoreBootstrap playerCore = PlayerCoreBootstrap.withComposition(
  composition: composition,
  foundationDependency: foundation,
);

final PlaybackPageContract playbackPage = PlaybackPageContract(
  controller: playerCore.controller,
);
```

For a selected local file, convert the selected path or file URI through the
handoff contract before opening playback:

```dart
final PlaybackSourceHandoffResult prepared =
    const LocalPlaybackSourceHandoff().prepare(
  PlaybackSourceHandoffInput.localMediaIdentity(localMediaIdentity),
);

if (prepared.isSuccess) {
  await playerCore.controller.open(prepared.source!);
}
```

UI widgets should observe `PlaybackControllerContract.currentState` and
`PlaybackStateObserver`, then dispatch user actions through
`PlaybackPageContract.dispatch(...)` or `PlaybackControllerContract`.

## Capability Rules

For the current concrete local-file composition, only these playback
capabilities are verified:

- `localFilePlayback`
- `playPause`
- `seek`
- `stop`

These must stay hidden or disabled until later capability-gated integration:

- HTTP/HLS playback
- progress reporting if absent from the active surface
- audio/subtitle track discovery or switching
- subtitle enhancement, advanced captions, and danmaku controls
- video enhancement, HDR, deband, Anime4K-style presets
- VLC fallback selection
- BT download and streaming controls
- diagnostics action controls

Unsupported paths are expected outcomes. Do not treat them as crashes.

## Validation Before UI Work

Run the core baseline before starting or after rebasing:

```powershell
openspec.cmd validate --all
powershell -ExecutionPolicy Bypass -File "tools\check_full_feature_gate.ps1"
```

Focused playback checks:

```powershell
flutter test test\ui\playback\flutter_playback_shell_test.dart
powershell -ExecutionPolicy Bypass -File "tools\check_player_core.ps1"
powershell -ExecutionPolicy Bypass -File "tools\check_player_smoke_gate.ps1"
```

The non-strict smoke gate may skip native playback when `libmpv-2.dll` is not
available. Release readiness requires strict native smoke:

```powershell
powershell -ExecutionPolicy Bypass -File "tools\check_full_feature_gate.ps1" `
  -RequireNativeSmoke `
  -LibMpvPath "<path-to-libmpv-2.dll-or-directory>" `
  -SampleMediaPath "<sample-local-video-file>"
```

## Packaged Release Check

After the frontend runner exists, package the Windows release output with the
bundled libmpv DLL:

```powershell
powershell -ExecutionPolicy Bypass -File "tools\package_windows_release.ps1" `
  -ReleaseDir "<build-windows-release-dir>" `
  -LibMpvPath "<path-to-libmpv-2.dll-or-directory>" `
  -OutputZip "<artifact-dir>\celesteria-windows.zip"
```

The release zip must contain the app executable and `libmpv-2.dll` in the same
directory. Customers should not need to install MPV or edit global `PATH`.

## Known Non-Ready Items

These are not blockers for frontend work, but they are blockers for final
customer delivery:

- no app entry point yet
- no real navigation shell yet
- no final playback page yet
- no file picker UX yet
- no video surface widget yet
- no packaged UI release artifact yet
- native smoke is not proven unless strict smoke runs with `libmpv-2.dll` and
  sample media
- some OpenSpec Purpose fields still contain legacy `TBD` text; use the
  concrete docs and exported contracts as the practical handoff source

## Frontend Acceptance Checklist

The first frontend handoff is successful when:

- `lib/main.dart` starts the desktop Flutter app
- the app composition root owns and disposes core runtime objects
- UI imports contracts from `package:celesteria/celesteria.dart` or approved
  UI-facing contract files
- local file selection opens playback through `LocalPlaybackSourceHandoff`
- playback controls are derived from `PlaybackPageSurfaceDescriptor`
- no UI file imports media_kit/libmpv/libtorrent/provider/storage/network
  concrete implementation details
- non-UI full gate still passes
- packaged Windows smoke proves unzip-and-run playback with bundled
  `libmpv-2.dll`
