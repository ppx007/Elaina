## ADDED Requirements

### Requirement: Network policy runtime SHALL provide a bootstrap acceptance layer
The system SHALL expose a Network Policy runtime bootstrap that composes a `NetworkPolicyStore`, scoped `NetworkPolicyEvaluator` instances, scoped `NetworkPolicyCapabilityMatrix` instances, and an optional `CacheInvalidationBus` without constructing concrete DNS, proxy, VPN, transport, diagnostics, UI, native, FFI, or platform implementations.

#### Scenario: Runtime is created from deterministic contracts
- **WHEN** the bootstrap receives a store, evaluator map, capability map, and optional bus
- **THEN** it creates a runtime that can return scoped projections and evaluate provider-scoped policy requests through the supplied contracts only

### Requirement: Network policy runtime SHALL return typed action outcomes
The runtime SHALL return typed `NetworkPolicyRuntimeActionResult<T>` values for snapshot, evaluation, provider assignment, disable, reenable, and capability recording operations, including compact runtime failure kinds for unsupported capability, unavailable runtime, disposed runtime, missing policy, disabled policy, invalid assignment, and evaluation failure.

#### Scenario: Unsupported capability blocks evaluation
- **WHEN** a provider scope lacks the required network policy capability
- **THEN** evaluation returns a typed `capabilityUnsupported` failure instead of invoking concrete network behavior

### Requirement: Network policy runtime SHALL rebuild projections from storage
The runtime SHALL expose projections and restart projections that read provider assignment, latest evaluation, latest block outcome, and capability state from `NetworkPolicyStore` so restart flows can replay policy state without re-evaluating traffic.

#### Scenario: Runtime restarts with stored policy state
- **WHEN** a new runtime starts for a provider scope with stored assignment, evaluation, block, and capability records
- **THEN** its snapshot projection reports that stored state without requiring DNS resolution, proxy transport, provider dispatch, or diagnostics execution

### Requirement: Network policy runtime SHALL publish store-visible invalidation events
The runtime SHALL publish existing network policy invalidation events through the optional cache invalidation bus only after related assignment, evaluation, block, or capability state is visible through storage contracts.

#### Scenario: Policy evaluation is blocked
- **WHEN** runtime evaluation returns a blocked decision and records the block outcome
- **THEN** `NetworkPolicyEvaluationOutcomeRecorded` and `NetworkPolicyBlockDecisionRecorded` are published after storage records are written

### Requirement: Network policy runtime MUST remain declarative and provider-scoped
The runtime MUST keep DNS, DoH, DoT, proxy, direct, block, fallback, and audit behavior as declarative provider-scoped policy intent and MUST NOT implement global routing, concrete clients, sockets, VPN/TUN behavior, packet inspection, provider dispatch, UI, native, FFI, or diagnostics actions.

#### Scenario: Provider request is evaluated
- **WHEN** a provider-scoped request is evaluated through the runtime
- **THEN** the result is a declarative policy decision and projection, not a transport dispatch or system-wide routing change
