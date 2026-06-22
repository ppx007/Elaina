# Frontend Supplemental Conventions

OpenSpec is the authority for UI behavior, page requirements, and cross-layer
contracts. This directory is only a supplemental convention library for Flutter
UI implementation and tests.

Do not treat generic placeholder files as authoritative. Prefer the active
codebase, OpenSpec specs, and stable UI test framework over old Trellis
templates.

## Read When Relevant

| Guide | Use When |
| --- | --- |
| [Component Guidelines](./component-guidelines.md) | Changing shared UI composition |
| [State Management](./state-management.md) | Moving state across UI/domain/runtime boundaries |
| [Quality Guidelines](./quality-guidelines.md) | Reviewing widget tests, dense layouts, and validation tiers |
| [Type Safety](./type-safety.md) | Changing projection or view-model types |

`hook-guidelines.md` is historical template material unless it has been updated
for Dart/Flutter. Elaina does not use React hooks.

## Validation

```powershell
dart analyze
dart run tools\elaina_tool.dart check changed --scope Fast
dart run tools\elaina_tool.dart check module --module <name>
openspec.cmd validate --all
```
