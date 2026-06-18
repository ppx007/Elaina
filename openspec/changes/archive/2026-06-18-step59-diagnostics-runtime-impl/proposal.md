# step59-diagnostics-runtime-impl

## Why

The archived diagnostics center runtime provides typed acceptance operations for
schemas, redacted events, snapshots, retention, export descriptors, and
capabilities. Step 59 should make that layer useful for real local diagnostics
without adding a UI surface or giving diagnostics control over playback,
providers, RSS, online rules, network policy, WebView, or BT.

## What Changes

- Add a Foundation-owned diagnostics invalidation collector that records local
  cache-invalidation observations through `DiagnosticsCenterRuntime`.
- Add a local export bundle builder that turns stored diagnostics snapshot and
  event records into a redacted, deterministic local payload.
- Add focused tests for collector lifecycle, schema registration, event
  recording, redaction preservation, snapshot filtering, export payload
  construction, and unsupported/disposed runtime outcomes.
- Extend diagnostics checker coverage for the concrete collector/export
  implementation and boundary cleanliness.

## Non-Goals

- No Flutter UI, app shell, diagnostics page, route, widget, file picker,
  `lib/main.dart`, or `windows/**` changes.
- No remote telemetry, crash reporter, analytics client, cloud upload, support
  bundle upload, filesystem writing, native plugin, platform channel, or FFI.
- No diagnostics operation that starts playback, mutates provider state, retries
  feeds, executes rules, modifies network policy, controls WebView challenges,
  or enqueues BT tasks.

## Validation

- Focused diagnostics runtime implementation tests.
- Diagnostics runtime checker and automation extension checker coverage.
- OpenSpec validation, analyzer, Flutter analyzer, and Flutter test baseline
  before archive.
