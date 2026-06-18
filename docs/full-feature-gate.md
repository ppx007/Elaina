# Full Feature Gate

Step 60 defines the non-UI release-readiness gate for the current core runtime
baseline.

Run it from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File "tools\check_full_feature_gate.ps1"
```

The gate composes the existing validators instead of replacing them:

- `openspec.cmd validate --all`
- `dart analyze`
- `flutter analyze`
- `flutter test`
- player core and player smoke gates
- ACG experience, library, automation, BT streaming, advanced playback, and
  diagnostics runtime checker coverage through existing scripts

Native player smoke remains explicit. On developer machines without `libmpv`,
the player smoke gate can report a skipped native step. For release readiness,
require native playback smoke:

```powershell
powershell -ExecutionPolicy Bypass -File "tools\check_full_feature_gate.ps1" -RequireNativeSmoke -LibMpvPath "D:\path\to\libmpv-2.dll" -SampleMediaPath "D:\path\to\sample.mp4"
```

Use `-SkipNativePlayerSmoke` only when validating non-native packaging or
contract-only changes.

## UI Boundary

This gate does not implement Flutter UI smoke automation, app shell behavior,
diagnostics pages, playback pages, video surfaces, file pickers, native runner
mutation, global PATH changes, remote telemetry, cloud upload, or support bundle
upload. UI-owned manual smoke remains outside Codex-owned Step 60 work.
