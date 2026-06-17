## ADDED Requirements

### Requirement: Step 42 media-library implementation SHALL preserve layer boundaries
Step 42 concrete media-library runtime work SHALL keep filesystem scanning and
storage-backed composition behind Domain/Foundation contracts while preserving
the external UI ownership boundary.

#### Scenario: Boundary checks scan Step 42 files
- **WHEN** media-library runtime validation scans Step 42 implementation,
  tests, tools, and docs
- **THEN** `lib/src/ui/**`, `lib/main.dart`, and `windows/**` remain untouched,
  SQLite and SQL details are found only in Foundation/Storage implementation
  and tests/tools, and Domain media runtime surfaces do not import provider
  clients, streaming engines, network clients, MPV/VLC bindings, or Flutter UI

