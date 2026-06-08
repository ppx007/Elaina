## Context

Celesteria has completed Phase 6 contract slices for RSS automation, online rule runtime, WebView session backfill, and provider-scoped network policy. These flows now produce typed failures, retry descriptors, capability states, storage records, and invalidation events, but diagnostics is still only a high-level registry/snapshot/export contract without durable storage, capability gating, deterministic scaffolding, or event propagation.

Step 30 closes the Phase 6 extension capability freeze by making diagnostics the local, read-only observability boundary across playback, BT, ProviderGateway, cache, rule-source, network-policy, storage, and A/V sync flows.

## Goals / Non-Goals

**Goals:**

- Define diagnostics capability contracts for local recording, schema registration, snapshot creation, filtering, export, retention enforcement, and redaction.
- Add deterministic diagnostics center scaffolding that can register schemas, redact payloads before persistence/export, query/filter events, create snapshots, and enforce bounded retention.
- Persist diagnostics schemas, events, snapshots, export request/outcome records, retention state, and capability state through Storage contracts.
- Publish cache invalidation events for diagnostics schema registration, event recording, snapshot creation, export lifecycle, retention enforcement, and capability changes.
- Preserve correlation identity across ProviderGateway failures, RSS/online-rule evaluations, WebView backfill attempts, network-policy decisions, playback, BT, cache, storage, and A/V sync records.
- Keep diagnostics optional for startup and core playback flows.

**Non-Goals:**

- No concrete SQLite table implementation, event ring buffer, file writer, platform diagnostics adapter, or background retention scheduler.
- No remote telemetry, crash reporting service, analytics pipeline, cloud upload, or automatic support bundle transmission.
- No diagnostics UI, settings screen, export dialog, or visualization layer.
- No lifecycle control: diagnostics must not start/stop playback, mutate providers, retry feeds, enqueue BT tasks, alter network policy, or control WebView challenges.
- No unredacted session artifacts, authorization headers, cookies, provider tokens, or local filesystem secrets in persisted/exported diagnostics payloads.

## Decisions

1. **Diagnostics is local-first and read-only.**
   Diagnostics contracts only record, filter, snapshot, and export local structured observations. They expose no commands that mutate the modules they observe, which preserves the existing strict boundary in the automation checker.

2. **Redaction happens before persistence and again at export boundaries.**
   The deterministic scaffolding should apply `DiagnosticsRedactionPolicy` before storing event payloads and before producing export descriptors. This avoids treating export as the only safety boundary and keeps storage safe by construction.

3. **Capability limits are explicit.**
   Platforms or builds can report unsupported local recording, snapshot, filtering, export, retention, or redaction capability. Unsupported diagnostics must degrade by returning typed failures rather than blocking local playback, RSS refresh, manual BT task creation, or ProviderGateway traffic.

4. **Storage keeps read models, not operational control.**
   Storage records schemas, events, snapshots, exports, retention state, and capability state. It must not expose methods named or shaped like playback/provider/BT/network control operations.

5. **CacheInvalidationBus carries diagnostics state changes.**
   Diagnostics events themselves are stored through diagnostics contracts, while cache invalidation events notify observers that schemas, recorded events, snapshots, exports, retention, or capabilities changed. This avoids point-to-point coupling between diagnostics and feature modules.

## Risks / Trade-offs

- **Risk: Diagnostics becomes a hidden control plane.** → Mitigation: contracts and checker forbid lifecycle/mutation operations such as playback control, provider mutation, feed retry, BT enqueue, and network-policy mutation.
- **Risk: Sensitive artifacts leak into diagnostics.** → Mitigation: redaction is required before persistence/export and tests/checkers cover sensitive key handling.
- **Risk: Diagnostics storage grows without bound.** → Mitigation: retention policy/state contracts and deterministic retention enforcement are part of this slice, without requiring a concrete background scheduler.
- **Risk: Users infer cloud telemetry.** → Mitigation: docs/specs/checkers explicitly forbid remote telemetry, analytics, crash reporting, cloud upload, and automatic support bundle transmission.
- **Risk: Diagnostics becomes mandatory for startup.** → Mitigation: capability contracts make diagnostics optional and failures must not block core playback, media library, RSS, online rules, manual BT tasks, WebView backfill, or network policy evaluation.
