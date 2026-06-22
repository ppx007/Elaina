## 1. Shared Test Support

- [x] 1.1 Add provider/gateway/Bangumi transport fakes under `test/support`.
- [x] 1.2 Add runtime fakes for cache invalidation, playback handoff, tracking,
  and common media/subject factories.
- [x] 1.3 Add UI host, video-detail repository/action, login, RSS, and scheduler
  fixtures.

## 2. Test Refactor

- [x] 2.1 Replace Bangumi runtime private gateway/transport fakes.
- [x] 2.2 Replace video-detail runtime private provider/tracking/cache fakes.
- [x] 2.3 Replace media-library and seasonal private Bangumi provider fakes.
- [x] 2.4 Replace UI host/detail/login/tracking/RSS fixture duplication.

## 3. Tools Refactor

- [x] 3.1 Add `tools/module_checks.json`.
- [x] 3.2 Add unified Dart validation and packaging CLI.
- [x] 3.3 Remove per-module Dart runtime-check entrypoints after adding the
  generic `tools/elaina_tool.dart check module --module <name>` CLI.
- [x] 3.4 Replace PowerShell module orchestration with registry-backed Dart
  runners.
- [x] 3.5 Update tool tests to validate registry coverage.

## 4. Documentation And Validation

- [x] 4.1 Update README with registry and generic runtime-check guidance.
- [x] 4.2 Run focused Dart/Flutter tests and sample module checks.
- [x] 4.3 Run OpenSpec validation.
