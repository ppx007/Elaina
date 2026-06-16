# Package Bundled MPV Windows Release

## Why

Step 31 proved the `media_kit` binding can drive libmpv when `libmpv-2.dll` is
discoverable. Production delivery needs a different guarantee:

- `libmpv-2.dll` is bundled beside the app executable.
- The binding prefers an explicit/bundled libmpv path over ambient machine PATH.
- Packaging automation verifies the release directory or zip contains the
  executable and `libmpv-2.dll`.
- The development-only `%LOCALAPPDATA%` smoke path remains a tool input, not a
  product contract.

## What Changes

Make the concrete MPV player path production-packaging aware. The previous
local smoke could pass only by prepending a developer-machine `%LOCALAPPDATA%`
directory to `PATH`; that is not an acceptable customer delivery model. A
Windows release artifact must be self-contained so customers can unzip the app
and run it without installing MPV or editing environment variables.

- Add Playback-owned bundled libmpv path resolution for Windows.
- Allow explicit libmpv path injection for smoke/tests.
- Add Windows release packaging/check tooling that stages `libmpv-2.dll` into a
  Flutter Windows release directory and produces a zip artifact.
- Keep UI implementation untouched.

## Non-Goals

- No Flutter pages, routes, widgets, file picker UX, or video surface work.
- No installer/MSIX work.
- No committing third-party binary DLLs into the repository.
- No global PATH mutation.
- No support for macOS/Linux packaging in this change.
