## 1. Diagnostics Center Contracts

- [x] 1.1 Add Foundation diagnostics capability matrix, capability status, typed failure/outcome contracts, local export descriptors, and retention outcome contract types.
- [x] 1.2 Add deterministic diagnostics registry and center scaffolding for schema registration, redacted event recording, query filtering, chronological snapshots, retention enforcement, and local export descriptor creation.
- [x] 1.3 Extend diagnostics query contracts to preserve category, severity, time range, correlation identity, source module, event type, and capability-area filters without introducing lifecycle-control actions.

## 2. Storage and Events

- [x] 2.1 Add Storage-layer contracts and deterministic store scaffolding for diagnostics schemas, redacted events, snapshots, export requests, export outcomes, retention state, and capability state.
- [x] 2.2 Export the diagnostics storage domain through StorageFoundation contracts and the public Dart contract barrel as appropriate.
- [x] 2.3 Add CacheInvalidationBus events for diagnostics schema registration, event recording, snapshot creation, export request/outcome recording, retention enforcement, and capability changes.

## 3. Gateway and Boundary Integration

- [x] 3.1 Add ProviderGateway-facing diagnostics correlation descriptors that preserve provider identity, request key, cache policy, failure classification, network-policy failure metadata, and correlation identity without dispatch or retry control.
- [x] 3.2 Extend Phase 6 documentation and automation boundary checkers so diagnostics remains local-first, read-only, redacted, bounded, and optional.
- [x] 3.3 Ensure contracts explicitly forbid remote telemetry, crash reporting, analytics, cloud upload, diagnostics UI actions, playback lifecycle control, provider mutation, feed retry, network-policy mutation, WebView challenge control, and BT enqueue/control.

## 4. Validation

- [x] 4.1 Add focused tests for diagnostics schema registration, redacted persistence, snapshot filtering, retention enforcement, local export descriptors, invalidation events, capability fallback behavior, and read-only boundary constraints.
- [x] 4.2 Update runtime checker coverage for diagnostics capabilities, storage records, redacted snapshots, export descriptors, correlation metadata, invalidation events, and forbidden remote/control behavior.
- [x] 4.3 Run `openspec validate "diagnostics-center-contract" --strict`, `openspec validate --all`, `dart analyze`, focused diagnostics tests, runtime checker, and automation boundary checker.
