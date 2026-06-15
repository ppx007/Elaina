## ADDED Requirements

### Requirement: Network policy boundary SHALL constrain the runtime acceptance layer
The network policy runtime acceptance layer SHALL remain a provider-scoped orchestration boundary over existing policy contracts, storage contracts, Gateway handoff value types, and cache invalidation events.

#### Scenario: Runtime evaluates provider traffic
- **WHEN** Gateway or Network code evaluates provider-scoped policy intent through the runtime
- **THEN** the runtime returns declarative allow/block/fallback/proxy/DNS intent without owning provider dispatch, DNS resolution, proxy transport, or system-wide routing

### Requirement: Network policy boundary MUST reject concrete networking leakage
Step 29 validation MUST reject runtime, test, and checker files that introduce concrete DNS clients, DoH clients, DoT clients, proxy clients, proxy servers, PAC parsers, VPN services, TUN interfaces, kernel filtering, DPI, packet capture, sockets, platform network plugins, UI widgets, native bindings, FFI, platform channels, or diagnostics implementation behavior.

#### Scenario: Boundary checker scans runtime slice
- **WHEN** Step 29 validation scans the network policy runtime files
- **THEN** forbidden concrete-networking, UI, native, platform, and diagnostics implementation terms fail validation before archive
