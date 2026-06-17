# Library Smoke Gate

Step 45 closes the non-UI Phase C path with a core-owned smoke gate:

```text
scan -> import -> detail -> playback handoff -> history -> continue-watching replay
```

Run it directly with:

```powershell
powershell -ExecutionPolicy Bypass -File "tools\check_library_smoke_gate.ps1"
```

## Coverage

The gate creates a temporary local media root, scans `.mkv` files with
`LocalFileMediaLibraryScanner`, imports candidates through
`storageBackedMediaLibraryBootstrap`, records playback progress with
`PlaybackHistoryRecorder`, loads detail data through
`storageBackedVideoDetailBootstrap`, routes playback through the existing
handoff contract, reopens SQLite storage, and verifies persisted
continue-watching state.

Provider metadata is deterministic and local to the gate. No live network,
provider transport client, native player binding, streaming engine, RSS, BT,
diagnostics runtime, Flutter widget, app shell, or file picker is required.

## UI Boundary

The external UI track can consume the same Domain/runtime contracts, but it
should not import this smoke tool or storage/native implementation details.
UI-owned code should pass selected directories into media-library contracts,
consume runtime snapshots, and call detail/playback actions through existing
Domain surfaces.
