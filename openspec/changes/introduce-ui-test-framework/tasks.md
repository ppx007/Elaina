## 1. Test Framework Contract

- [x] 1.1 Add OpenSpec requirements for stable UI ids, Robot/TestKit usage,
  integration smoke, and declarative test-suite selection.
- [x] 1.2 Add production UI element id constants and move touched raw keys to
  those constants.
- [x] 1.3 Add `integration_test` dev dependency.

## 2. Internal TestKit

- [x] 2.1 Add `ElainaTestHarness` for shell/app pumping with default fake
  runtimes.
- [x] 2.2 Add centralized `ElainaFinders` and screen robots.
- [x] 2.3 Reuse existing `test/support` fake providers/runtime helpers instead
  of duplicating them in migrated tests.

## 3. Test Migration

- [x] 3.1 Migrate `test/widget_test.dart` shell/search flows to harness and
  robots.
- [x] 3.2 Migrate `test/ui/settings_and_diagnostics_test.dart` to shared host,
  robots, and stable ids.
- [x] 3.3 Add integration smoke test for startup and key page reachability.

## 4. Validation Control

- [x] 4.1 Add `tools/test_suites.json`.
- [x] 4.2 Refactor changed-test selection to read the registry through the
  Dart CLI.
- [x] 4.3 Preserve `Fast`, `Module`, `Full`, `ChangedPath`, and `DryRun`
  behavior.

## 5. Validation

- [x] 5.1 Run `dart analyze`.
- [x] 5.2 Run migrated focused widget tests.
- [x] 5.3 Run `dart run tools/elaina_tool.dart check changed --scope Fast`.
- [x] 5.4 Run `openspec.cmd validate --all`.
