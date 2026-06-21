## Why

Runtime tests and tool entrypoints have drifted into repeated fake providers,
recording gateways, cache buses, UI hosts, PowerShell proxies, and Dart wrapper
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
  modules, public PowerShell check scripts, legacy scripts, Dart entrypoints,
  contracts, and focused tool tests.
- Add `tools/runtime_check.dart --module <name>` plus a shared Dart proxy so
  existing `tools/*_runtime_check.dart` files stay as stable compatibility
  entrypoints without per-file wrapper classes.
- Teach `Invoke-ModuleCheck.ps1` to read registry defaults before falling back
  to legacy script resolution.
- Update README validation guidance for registry-backed runtime checks.

## Impact

- Affects test support, focused Bangumi/detail/media/seasonal/UI tests,
  runtime-check tooling, `Invoke-ModuleCheck.ps1`, README, and tool tests.
- Keeps public `tools/check_*.ps1` and `tools/*_runtime_check.dart` entrypoints
  available.
- Does not remove legacy PowerShell scripts yet; registry now points to them
  explicitly so later migration can delete them module by module.
