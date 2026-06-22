## Why

High-churn UI tests currently bind directly to localized text, layout shape,
private fake runtimes, and raw `WidgetTester` operations. Small page changes
therefore force broad test rewrites even when the user-visible behavior has
not changed.

The repository already has shared fakes and runtime-check registries. The
missing layer is a stable UI testing contract: named element ids, a reusable
app harness, screen robots, and a declarative test-suite selector.

## What Changes

- Add stable production UI element ids for navigation, search, settings,
  detail, downloads, RSS, and carousel targets.
- Add a `test/framework` TestKit with an app/shell harness, focused fake app
  runtimes, centralized finders, and screen robots.
- Migrate the highest-churn shell/settings/media/downloads/RSS tests to use
  the harness and robots for navigation and controls while keeping
  user-visible content assertions where they carry behavior.
- Add official Flutter `integration_test` as the desktop smoke-test entry.
- Replace hardcoded changed-test selection with `tools/test_suites.json` and
  the Dart `tools/elaina_tool.dart check changed` command.

## Impact

- Affects UI tests, test support code, the changed-test gate, and stable UI key
  constants.
- Does not introduce Patrol or golden testing in this round.
- Does not change business runtime behavior.
