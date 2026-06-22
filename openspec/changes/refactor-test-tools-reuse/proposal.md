## Why

Runtime tests and tool entrypoints have drifted into repeated fake providers,
recording gateways, cache buses, UI hosts, shell proxies, and Dart wrapper
classes. That duplication makes every Bangumi/detail/UI change pay a tax: new
provider methods must be copied into multiple private fakes, and runtime-check
module wiring is inferred from filenames instead of a declared registry.

## What Changes

- Add shared test support fakes for ProviderGateway, Bangumi provider/API
  transport, cache invalidation, playback handoff, Bangumi tracking/sync, and
  common UI host/action fixtures.
- Replace duplicated Bangumi/detail/media/seasonal/UI test fakes with the
  shared support layer while keeping scenario data local to each test.
- Add a declarative `tools/module_checks.json` registry for runtime-check
  modules, contracts, required files, focused tool tests, and boundary terms.
- Add `tools/elaina_tool.dart check module --module <name>` as the single Dart
  runtime-check entrypoint and remove per-module `tools/*_runtime_check.dart`
  wrapper files.
- Replace PowerShell module orchestration with the Dart CLI and registry.
- Update README validation guidance for registry-backed runtime checks.

## Impact

- Affects test support, focused Bangumi/detail/media/seasonal/UI tests,
  runtime-check tooling, README, and tool tests.
- Removes tracked PowerShell check entrypoints and consolidates active tooling
  behind the Dart CLI.
