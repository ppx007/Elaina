# Player Runtime Composition Contract

This note is the Step 32 integration contract for external app-shell/UI work.
Codex-owned core code provides playback runtime inputs; the external UI track
owns Flutter pages, navigation, file picker UX, and video-surface rendering.

## Ownership

Codex-owned code may create Playback and Domain runtime objects:

```dart
final PlayerRuntimeCompositionContract composition =
    mediaKitLocalFilePlayerRuntimeComposition(libmpvPath: optionalLibMpvPath);

final PlayerCoreBootstrap playerCore = PlayerCoreBootstrap.withComposition(
  composition: composition,
  foundationDependency: foundation,
);
```

UI-owned code consumes only stable contracts such as
`PlaybackControllerContract`, `PlaybackStateSnapshot`,
`PlaybackCapabilityMatrix`, `PlaybackPageContract`, and
`PlayerCoreBootstrap`. UI code must not import `package:media_kit`,
libmpv-specific packages, VLC bindings, provider clients, storage internals,
streaming engines, or network implementations directly.

## Local File Playback

Use `mediaKitLocalFilePlayerRuntimeComposition(...)` for the first real local
file playback path. It enables only verified capabilities:

- `localFilePlayback`
- `playPause`
- `seek`
- `stop`

HTTP, HLS, track discovery, and track switching remain unsupported until a
later change implements and validates them.

See `docs/player-capability-gate.md` for the Step 33 UI-facing capability
gate: playback pages should render and dispatch only from the active surface
descriptor or capability matrix.

See `docs/player-ui-integration-contract.md` for the Step 34 source handoff,
lifecycle observation, disposal, and normalized error contract for external UI
work.

The optional `libmpvPath` may point to `libmpv-2.dll` or to a directory
containing it. When omitted on Windows, the binding looks for
`libmpv-2.dll` beside the running executable. That is the production packaging
path for unzip-and-run releases.

## Packaged Release Smoke

After the external UI model adds a Windows desktop runner, produce a release
directory and run:

```powershell
powershell -ExecutionPolicy Bypass -File "tools\package_windows_release.ps1" `
  -ReleaseDirectory "<build-windows-release-dir>" `
  -LibMpvPath "<path-to-libmpv-2.dll-or-directory>" `
  -OutputZip "<artifact-dir>\celesteria-windows.zip"
```

The generated zip must contain the app executable and `libmpv-2.dll` in the
same directory. Customers should not need to install MPV or edit global `PATH`.

For a non-UI native smoke, run:

```powershell
dart run tools\media_kit_mpv_binding_smoke.dart `
  --libmpv "<path-to-libmpv-2.dll-or-directory>" `
  "<sample-local-video-file>"
```
