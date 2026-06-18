## Context

The diagnostics center runtime acceptance layer already persists redacted local
events, snapshots, export descriptors, retention state, and capability state. It
does not yet provide a concrete local collector or a deterministic export
payload builder for stored snapshots.

## Goals / Non-Goals

**Goals:**

- Collect local `CacheInvalidationEvent` observations as diagnostics events.
- Keep collection generic and read-only so diagnostics does not depend on
  concrete module APIs or control any module lifecycle.
- Build redacted local export bundles from existing diagnostics store records.
- Preserve capability gates and typed runtime outcomes.

**Non-Goals:**

- No UI or app-shell ownership.
- No remote upload, file writing, native plugin, FFI, or platform channel.
- No concrete playback/provider/RSS/online-rule/network/WebView/BT commands.

## Decisions

- Use `CacheInvalidationEvent.runtimeType.toString()` as observation metadata
  instead of importing module-specific event classes into the collector.
- Register a single diagnostics schema for invalidation observations. This
  avoids per-module schema churn and keeps the collector generic.
- Build export bundles from `DiagnosticsStore` records rather than from
  in-memory runtime state, so restart/replay behavior remains deterministic.
- Keep output as a payload object plus JSON lines. The implementation describes
  export content without owning filesystem writes or remote transport.

## Risks / Trade-offs

- Generic invalidation observations carry less module-specific detail than a
  future dedicated collector. Mitigation: the payload keeps event type,
  source module, correlation identity, and occurred-at metadata without crossing
  layer boundaries.
- Export bundle construction depends on snapshot event IDs. Mitigation: missing
  event records are skipped rather than synthesized, preserving store truth.
