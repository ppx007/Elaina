# Elaina

Elaina is an end-side-first cross-platform ACG player built with Flutter and
Dart. The repository focuses on application source code, tests, runtime
adapters, and packaging tools.

## Source Layout

```text
lib/      Application and runtime source code.
test/     Dart and Flutter tests.
tools/    Local validation and packaging CLI.
deploy/   Deployment templates used by runtime features.
assets/   Application assets.
```

## Development

Install Flutter and fetch dependencies:

```powershell
flutter pub get
```

Run static analysis:

```powershell
dart analyze
```

Run the fast changed-path validation gate:

```powershell
dart run tools\elaina_tool.dart check changed --scope Fast
```

Run focused Flutter tests by path while iterating:

```powershell
flutter test test\widget_test.dart
```

## Repository Hygiene

- Keep the public repository focused on source code, tests, assets, build
  manifests, runtime tools, and this README.
- Do not commit local AI tool configuration, planning systems, generated
  indexes, personal session history, or development notes.
- Keep local-only material ignored by Git before staging changes.
- Do not commit, push, configure remotes, or publish without an explicit user
  request.
