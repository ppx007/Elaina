# Player Smoke Gate

Step 35 defines the core-owned smoke gate for Phase A local playback. It does
not implement UI. It verifies the two things Codex owns before the external UI
track joins:

1. A Windows release directory can be packaged with an app executable and
   `libmpv-2.dll` side by side.
2. The concrete media_kit/libmpv binding can run a non-UI local playback
   command sequence when native dependencies are available.

## Core Smoke

Run the smoke gate with an explicit libmpv DLL or a directory containing it:

```powershell
powershell -ExecutionPolicy Bypass -File "tools\check_player_smoke_gate.ps1" `
  -LibMpvPath "<path-to-libmpv-2.dll-or-directory>" `
  -RequireNativeSmoke
```

If `-SampleMediaPath` is omitted and `ffmpeg` is available, the gate generates
a temporary MP4 outside the repository. If `ffmpeg` is unavailable, provide a
local sample file:

```powershell
powershell -ExecutionPolicy Bypass -File "tools\check_player_smoke_gate.ps1" `
  -LibMpvPath "<path-to-libmpv-2.dll-or-directory>" `
  -SampleMediaPath "<sample-local-video-file>" `
  -RequireNativeSmoke
```

The script reuses:

- `tools/package_windows_release.ps1`
- `tools/media_kit_mpv_binding_smoke.dart`

Temporary release directories, zips, and generated sample media are created
under the system temp directory and removed after the run. Native binaries are
not copied into the repository.

## Non-Strict Machines

For machines without native dependencies, the same script may run without
`-RequireNativeSmoke`. Missing `libmpv-2.dll` is reported as an explicit skip
instead of being mistaken for a successful native playback check:

```powershell
powershell -ExecutionPolicy Bypass -File "tools\check_player_smoke_gate.ps1"
```

This mode is acceptable for generic baseline checks. Release readiness requires
strict native smoke with `libmpv-2.dll`.

## External UI Joined Smoke

After the external UI model adds `lib/main.dart`, app shell, file picker,
playback page, video surface, and Windows runner, use the real release output:

```powershell
powershell -ExecutionPolicy Bypass -File "tools\package_windows_release.ps1" `
  -ReleaseDir "build\windows\x64\runner\Release" `
  -LibMpvPath "<path-to-libmpv-2.dll-or-directory>" `
  -OutputZip "build\dist\celesteria-windows-x64.zip"
```

The zip must allow unzip-and-run local playback without customer MPV
installation or global `PATH` edits. UI smoke remains external-model owned,
but it must consume the contracts documented in
`docs/player-ui-integration-contract.md`.
