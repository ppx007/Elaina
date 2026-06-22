# Frontend Handoff

| Field | Value |
| --- | --- |
| Document version | 1.1 |
| Last updated | 2026-06-18 |
| Status | Active — core baseline complete through Step 60 (full feature gate) |
| Audience | External frontend / UI implementation track |
| Core owner contact | See repository `CODEOWNERS` / project lead |
| Source of truth | Exported contracts in `lib/elaina.dart` + the concrete docs linked below |

This document is the entry point for the external frontend/UI implementation
track. The current repository is ready for frontend development against stable
core contracts, but it is not a complete end-user app yet.

## Environment Prerequisites

Match these before building. Mismatched SDK/toolchain versions are the most
common cause of "works on core, breaks on frontend" reports.

- Dart SDK: `>=3.4.0 <4.0.0` (per `pubspec.yaml`).
- Flutter: 3.44.0 stable (toolchain the core baseline was validated against).
- Platform target: Windows desktop is the validated delivery target. The
  `windows/` (and other platform) runner folders do **not** exist yet —
  frontend must run `flutter create --platforms=windows .` (and any other
  targets) to scaffold them. This is expected, not a defect.
- Native dependency: `libmpv-2.dll` is required for real local playback and for
  strict native smoke. It is not committed; obtain it out of band.
- Key package versions (from `pubspec.yaml`): `libtorrent_flutter ^1.8.5`,
  `media_kit ^1.2.6`, `media_kit_libs_windows_video ^1.0.11`, `sqlite3 ^3.3.3`,
  `xml ^7.0.1`. Do not add or upgrade these from UI code without core sign-off.

## Current Readiness

The core/runtime baseline is complete through Step 60:

- OpenSpec is the active workflow authority.
- Core runtime, provider, storage, playback, streaming, diagnostics, and smoke
  gates are implemented and archived through the full feature gate.
- Public contracts are exported from `lib/elaina.dart`.
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

> **Important — the barrel does not enforce this for you.**
> `package:elaina/elaina.dart` is a single barrel that currently
> re-exports *every* `lib/src/**` file, including the concrete backends listed
> below. Importing the barrel therefore makes forbidden symbols *visible*. The
> boundary is a **discipline rule the UI layer must self-enforce**, backed by
> review and the lint/grep guard described in
> [UI Boundary Self-Check](#ui-boundary-self-check) — not something the import
> graph prevents today. Treat any reference to a forbidden symbol as a defect
> even though it compiles.

Do not import or branch on:

- `package:media_kit`
- libmpv handles or media-kit player objects (`MediaKitMpvBinding`, `NativePlayer`)
- VLC concrete backend objects (`VlcFallbackAdapter`)
- libtorrent concrete engine objects (`LibtorrentDownloadEngineAdapter`)
- Bangumi or Dandanplay API client internals (`BangumiApiClient`, `DandanplayApiClient`)
- OpenSubtitles API client internals (`OpenSubtitlesApiClient`)
- SQLite/drift/sqlite3 storage internals (`SqliteStorageFoundation`)
- WebView/network implementation details (`NetworkPolicy*`, `WebViewSessionBackfill*`)
- smoke tools under `tools/`

Use capability data instead of backend knowledge. If a capability is not
declared as supported, the UI must hide or disable the related control instead
of calling a concrete adapter directly.

### UI Boundary Self-Check

Until a dedicated UI-facing barrel exists, gate UI code with a grep guard in CI
or a pre-commit hook (adjust the UI source root as needed):

```powershell
# Fails if any UI file imports a forbidden concrete backend.
$hits = Select-String -Path "lib\ui\**\*.dart","lib\main.dart" `
  -Pattern "media_kit|libtorrent|bangumi_api_client|dandanplay_api_client|opensubtitles_provider|sqlite_storage_foundation|network_policy|webview_session_backfill|vlc_fallback_adapter|media_kit_mpv_binding" `
  -ErrorAction SilentlyContinue
if ($hits) { $hits; throw "UI imports a forbidden concrete backend." }
```

If the core team later publishes a curated UI-facing barrel (e.g.
`package:elaina/ui.dart`), switch UI imports to it and this guard becomes a
backstop.

## Primary Entry Points

Read these first:

- `lib/elaina.dart`
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

Provider/metadata contracts (domain-facing; consume these, not the
provider-layer `*ProviderRuntime` classes):

- `AcgExperienceRuntime`
- `BangumiAcgRuntime`
- `DandanplayAcgRuntime`
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

Observe state and dispatch intents (note `PlaybackStateObserver` is an
interface with a single `onPlaybackState(PlaybackStateSnapshot)` method, not a
`Stream`):

```dart
class _PlaybackBinder implements PlaybackStateObserver {
  _PlaybackBinder(this._controller, this._page) {
    _controller.addPlaybackStateObserver(this); // remember to remove on dispose
  }

  final PlaybackControllerContract _controller;
  final PlaybackPageContract _page;

  @override
  void onPlaybackState(PlaybackStateSnapshot snapshot) {
    // rebuild UI from snapshot (idle/playing/paused, position, etc.)
  }

  Future<void> onPlayPressed() async {
    final PlaybackPageIntentResult result =
        await _page.dispatch(const PlaybackPageIntent.play());
    // result is one of: executedCommand / executedTrackSwitch / executedPanel /
    // ignored(reason) / unsupported(reason). Treat ignored/unsupported as
    // expected, non-crash outcomes — surface them as a disabled/hidden control.
  }

  void dispose() => _controller.removePlaybackStateObserver(this);
}
```

Gate every optional control on the capability matrix rather than on backend
knowledge:

```dart
final PlaybackCapabilityMatrix caps = playerCore.runtime.capabilityMatrix;
final bool canSeek = caps.statusOf(PlaybackCapability.seek).isSupported;
// Render the seek bar only when canSeek is true.
```

## Failure & Lifecycle Contract

- Handoff: `LocalPlaybackSourceHandoff.prepare(...)` returns a
  `PlaybackSourceHandoffResult`. Check `isSuccess` before reading `source!`; on
  failure, read `failure` and show a typed error — never assume success.
- Intents: `PlaybackPageContract.dispatch(...)` returns a typed
  `PlaybackPageIntentResult`. `ignored` and `unsupported` are normal control-flow
  outcomes, not exceptions.
- Commands: `PlaybackControllerContract.open(...)` returns a
  `PlaybackCommandResult`; inspect it instead of assuming the open succeeded.
- Lifecycle/threading: runtime objects are single-owner. The app composition
  root creates them once, holds them for app lifetime, and disposes them on
  shutdown. Do not create per-widget runtimes. Always pair
  `addPlaybackStateObserver` with `removePlaybackStateObserver` in widget
  dispose to avoid leaks. Runtimes are not guaranteed thread-safe across
  isolates — drive them from the UI isolate.

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
dart run tools\elaina_tool.dart check full
```

Focused playback checks:

```powershell
flutter test test\ui\playback\flutter_playback_shell_test.dart
dart run tools\elaina_tool.dart check module --module player_core
dart run tools\elaina_tool.dart check full --skip-native-player-smoke
```

The non-strict smoke gate may skip native playback when `libmpv-2.dll` is not
available. Release readiness requires strict native smoke:

```powershell
dart run tools\elaina_tool.dart check full `
  --require-native-smoke `
  --libmpv-path "<path-to-libmpv-2.dll-or-directory>" `
  --sample-media-path "<sample-local-video-file>"
```

## Packaged Release Check

After the frontend runner exists, package the Windows release output with the
bundled libmpv DLL:

```powershell
dart run tools\elaina_tool.dart package windows-release `
  --release-dir "<build-windows-release-dir>" `
  --libmpv-path "<path-to-libmpv-2.dll-or-directory>" `
  --output-zip "<artifact-dir>\elaina-windows.zip"
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
- UI imports contracts from `package:elaina/elaina.dart` or approved
  UI-facing contract files
- local file selection opens playback through `LocalPlaybackSourceHandoff`
- playback controls are derived from `PlaybackPageSurfaceDescriptor`
- no UI file imports media_kit/libmpv/libtorrent/provider/storage/network
  concrete implementation details
- non-UI full gate still passes
- packaged Windows smoke proves unzip-and-run playback with bundled
  `libmpv-2.dll`

## Definition of Done (Deliverable Standard)

Delivery is graded against three tiers. A tier is "done" only when every line
is objectively verifiable by the listed command or artifact — not by
inspection alone.

### Tier 1 — Frontend Milestone Accepted (local playback usable)

| # | Criterion | How it is verified |
| --- | --- | --- |
| 1 | `lib/main.dart` launches the desktop app | `flutter run -d windows` opens a window |
| 2 | Composition root creates and disposes runtimes once | Code review + no leaked runtime per widget |
| 3 | UI consumes only contracts (no forbidden imports) | [UI Boundary Self-Check](#ui-boundary-self-check) passes |
| 4 | File picker → `LocalPlaybackSourceHandoff` → `controller.open` | Manual: pick a local file, playback starts |
| 5 | Controls derived from `PlaybackPageSurfaceDescriptor` / capability matrix | No control shown for an unsupported capability |
| 6 | `ignored`/`unsupported` intent results handled without crashing | Manual: trigger an unsupported control |
| 7 | Non-UI full gate still green | `dart run tools\elaina_tool.dart check full` |
| 8 | UI widget smoke present and green | `flutter test test\ui\playback\flutter_playback_shell_test.dart` |
| 9 | `dart analyze` clean for the whole repo | `dart analyze` → "No issues found" |

### Tier 2 — Release Candidate (packaged, native-proven)

Everything in Tier 1, plus:

| # | Criterion | How it is verified |
| --- | --- | --- |
| 1 | Strict native smoke proven | `dart run tools\elaina_tool.dart check full --require-native-smoke --libmpv-path ... --sample-media-path ...` |
| 2 | Windows release packages cleanly | `dart run tools\elaina_tool.dart package windows-release ...` produces the zip |
| 3 | Zip contains app exe + `libmpv-2.dll` in the same directory | Inspect the produced artifact |
| 4 | Unzip-and-run on a clean machine plays a local file | Manual on a machine without MPV installed / no `PATH` edits |
| 5 | App starts, opens, plays, seeks, pauses, stops without unhandled errors | Manual playback session |

### Tier 3 — Customer Delivery (full product)

Everything in Tier 2, plus the feature surfaces gated behind later capability
work are wired and verified as they are enabled by core: HTTP/HLS playback,
track discovery/switching, subtitle/danmaku/enhancement controls, BT
download/streaming UI, and diagnostics action controls. Each must be turned on
only when its capability reports `supported`, and each gets its own manual UI
smoke for the packaged build.

### Sign-off

A tier is delivered when:

- every row's verification command/artifact has been run and recorded (paste
  command output or attach the artifact in the handoff PR), and
- the [Known Non-Ready Items](#known-non-ready-items) relevant to that tier are
  resolved or explicitly waived by the core owner.

Record the verifying commit SHA, the toolchain versions used (see
[Environment Prerequisites](#environment-prerequisites)), and the `libmpv-2.dll`
source/version alongside the sign-off.
