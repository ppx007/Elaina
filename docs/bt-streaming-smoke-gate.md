# BT Streaming Smoke Gate

Step 55 adds a non-UI smoke gate for the Phase 4 BT streaming path:

```text
BT task -> virtual stream -> byte range -> priority application
```

The gate creates a deterministic libtorrent-backed task through the
`LibtorrentEngineBackend` boundary, persists metadata and file selection,
creates a virtual stream for the selected file, serves bytes through
`FileVirtualByteSource`, generates a playback-window priority plan, and applies
that plan through the concrete libtorrent file-priority boundary.

## UI Boundary

This smoke gate does not implement a download page, playback page, video
surface, timeline overlay, file picker, route, app shell, `lib/main.dart`, or
`windows/**` packaging. UI code should consume the existing runtime contracts
after an external UI implementation wires the app shell.

## Native Boundary

The current libtorrent Dart surface supports file-priority application. Step 55
therefore validates selected-file priority application and does not claim a
native per-piece API that the package does not expose.
