# step54-piece-priority-application

## Why

Step 53 can serve selected file byte ranges, and the piece priority scheduler
already generates durable playback/seek plans. Step 54 should connect those
plans to a concrete BT-engine-owned application boundary so accepted/rejected
outcomes reflect a real adapter call, while keeping UI, timeline overlays,
native playback, and neutral scheduler runtime isolated.

## What Changes

- Add a libtorrent-owned `PiecePriorityPlanApplier` implementation.
- Apply scheduler plans through the libtorrent adapter/backend boundary using
  the available file-priority API for the plan's backing file.
- Declare piece-priority scheduling capability when the concrete libtorrent
  adapter can accept scheduler plan application.
- Add focused tests proving accepted and rejected plan application outcomes are
  recorded through `PiecePrioritySchedulerRuntime.applyPlan(...)`.
- Update boundary checker coverage so concrete BT package usage remains
  limited to approved Streaming adapter code and tests.

## Non-Goals

- No Flutter UI, download page, playback page, timeline overlay, route,
  `lib/main.dart`, or `windows/**` changes.
- No HTTP/range server, socket server, pipe server, WebView, diagnostics,
  RSS automation, network policy, storage migration, or native player work.
- No fake per-piece native API. The current libtorrent Flutter Dart surface
  exposes file priority application; arbitrary native per-piece priority or
  deadline control remains outside this change unless the concrete package
  exposes that API later.

## Validation

- Focused libtorrent adapter and piece priority scheduler tests.
- BT streaming checker script.
- OpenSpec validate, analyzer, and full Flutter test baseline before archive.
