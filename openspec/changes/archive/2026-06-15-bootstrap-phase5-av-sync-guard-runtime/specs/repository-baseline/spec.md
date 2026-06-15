## MODIFIED Requirements

### Requirement: Repository baseline SHALL record Step 23 AV sync guard runtime boundary
The repository baseline SHALL record that Step 23 adds the AV sync guard runtime acceptance layer (bootstrap, scoped projections, typed outcomes, restart replay, dispose/unavailable gates) and that concrete MPV timing probes, native FFI bindings, VLC fallback selection, diagnostics center integration, network policy, RSS automation, WebView session handling, and Flutter rendering remain outside the Step 23 slice boundary.

#### Scenario: Step 23 runtime boundary is documented
- **WHEN** future changes reference which capabilities Step 23 introduced
- **THEN** the repository baseline records that Step 23 added `AVSyncGuardBootstrap`, `AVSyncGuardRuntime`, typed outcome types, projection types, and restart replay without introducing native, renderer, diagnostics, network, or UI dependencies
