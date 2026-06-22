# Backend Supplemental Conventions

OpenSpec is the authority for Elaina behavior and cross-layer contracts. This
directory is only a supplemental convention library for backend-shaped Dart
code such as provider, gateway, storage, streaming, playback, diagnostics, and
tooling runtimes.

Do not treat generic placeholder files as authoritative. If a linked file has
not been made Elaina-specific, use the active code and OpenSpec instead.

## Read When Relevant

| Guide | Use When |
| --- | --- |
| [Directory Structure](./directory-structure.md) | Moving or adding backend/runtime files |
| [Error Handling](./error-handling.md) | Changing failure normalization or runtime boundaries |
| [Quality Guidelines](./quality-guidelines.md) | Reviewing magic values, fallback behavior, and validation |
| [Logging Guidelines](./logging-guidelines.md) | Touching diagnostics or runtime events |

`database-guidelines.md` is retained as historical template material. Elaina
does not currently use it as an active storage authority; storage behavior
belongs in OpenSpec and the Dart code.

## Validation

```powershell
dart analyze
dart run tools\elaina_tool.dart check changed --scope Fast
dart run tools\elaina_tool.dart check module --module <name>
openspec.cmd validate --all
```
