## Why

Phase 6 Step 30 is the final automation-extension contract slice: the diagnostics center must become the local, typed observability boundary for playback, BT, ProviderGateway, cache, rule-source, network-policy, storage, and A/V sync flows. Existing diagnostics contracts define basic registry, snapshot, redaction, and export shapes, but they do not yet define storage persistence, capability gating, invalidation events, deterministic scaffolding, or executable validation coverage.

## What Changes

- Deepen diagnostics center contracts with capability status for local event recording, schema registration, snapshot creation, filtering, export, retention enforcement, and redaction.
- Add deterministic diagnostics center scaffolding for schema registration, redacted local event recording, query filtering, snapshot creation, export descriptors, and retention enforcement.
- Persist diagnostics schemas, events, snapshots, export requests/outcomes, retention state, and capability state through Storage contracts.
- Publish explicit cache invalidation events when diagnostics schemas are registered, events are recorded, snapshots are created, retention is enforced, exports are requested/recorded, or capability state changes.
- Extend documentation, runtime checks, automation checkers, and focused tests so diagnostics remains read-only, local-first, bounded, redacted, and optional.
- Keep this contract-only: no concrete database implementation, remote telemetry, crash reporting service, analytics pipeline, cloud upload, diagnostics UI, lifecycle control, provider mutation, playback control, BT enqueue, feed retry, or network-policy mutation.

## Capabilities

### New Capabilities

- `diagnostics-center-contract`: Typed contracts for local diagnostics capability gating, deterministic event registry/center/export scaffolding, storage persistence, invalidation events, retention, and redaction.

### Modified Capabilities

- `diagnostics-center`: Deepen diagnostics requirements for capability limits, durable local state, deterministic read-only scaffolding, correlation threading, export descriptors, retention, and redaction boundaries.
- `local-storage-foundation`: Add Storage-layer responsibilities for diagnostics schemas, events, snapshots, exports, retention state, and capability state.
- `cache-invalidation-bus`: Add diagnostics invalidation events for schema registration, event recording, snapshot creation, export lifecycle, retention enforcement, and capability changes.
- `provider-gateway`: Require diagnostics correlation metadata for provider-facing failures without allowing diagnostics to dispatch, retry, or mutate provider traffic.

## Impact

- Affected layers: Foundation diagnostics, Storage, Gateway contracts, cache invalidation, docs, tests, and checker tooling.
- Expected code impact: Dart contract types in `lib/src/foundation/diagnostics/diagnostics_center.dart`, new diagnostics storage contracts, StorageFoundation exports, CacheInvalidationBus event types, focused tests, runtime checker coverage, automation boundary checker updates, and Phase 6 documentation updates.
- No new runtime dependency is required; concrete persistence, UI, export file writers, telemetry, crash reporting, and platform diagnostics adapters remain future work.
