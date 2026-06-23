## Why

The settings center currently exposes mutable global preferences, but it lacks
a stable place for read-only project information. Users need to see what the
software is, its current version, the project repository, and the upstream
projects/services it relies on without hunting through docs or source files.

## What Changes

- Add an "About" section to the settings navigation.
- Show Elaina name, code name, version, project positioning, and repository.
- Show reference repositories or public project pages for core upstream
  dependencies and services.
- Keep this section read-only; it must not create fake preferences or write to
  settings storage.

## Impact

- Affects settings UI, stable UI ids, settings robots/finders, OpenSpec, and
  settings widget tests.
- Does not add a browser launcher dependency; URLs are displayed as selectable
  text for now.
