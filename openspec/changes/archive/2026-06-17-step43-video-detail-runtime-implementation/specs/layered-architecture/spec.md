## ADDED Requirements

### Requirement: Step 43 video-detail implementation SHALL preserve layer boundaries
Step 43 concrete video-detail runtime work SHALL keep storage-backed detail
composition behind Domain/Foundation contracts while preserving the external
UI ownership boundary.

#### Scenario: Boundary checks scan Step 43 files
- **WHEN** video-detail runtime validation scans Step 43 implementation, tests,
  tools, and docs
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  SQLite and SQL details stay inside Foundation/Storage implementation and
  tests/tools, and Domain detail runtime surfaces do not import concrete
  provider transports, ProviderGateway runtime internals, streaming engines,
  network clients, MPV/VLC bindings, Flutter widgets, RSS automation, or
  diagnostics implementations
