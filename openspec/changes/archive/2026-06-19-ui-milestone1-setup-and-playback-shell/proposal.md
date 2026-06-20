## Why

The core runtime and contract scaffolding for Celesteria (1017) are fully established through Phase 6 (Step 60), but the repository currently lacks a runnable desktop application entry point, a real navigation shell, and a production-ready local playback page. Implementing these UI features under the spec-driven workflow is required to achieve the first frontend milestone (usable local playback on Windows desktop).

## What Changes

- **Desktop App Entry Point**: Create `lib/main.dart` as the root entry point for the Flutter application on Windows.
- **Composition Root**: Instantiate the long-lived player runtime composition (`mediaKitLocalFilePlayerRuntimeComposition`) and dependencies once at startup and ensure proper disposal on app close.
- **Design System & Theme**: Establish a centralized `CelesteriaTheme` under `lib/src/ui/theme/` to manage colors (dark glassmorphism), spacing, typography, and visual assets without magic values.
- **Navigation Shell**: Implement a responsive desktop layout with a sidebar/rail representing navigation options (Home, Media Library, Playback, Downloads, RSS, Settings, Diagnostics).
- **Production Playback Page**: Replace/extend the mock-rendered page with a capability-driven page consuming `PlaybackPageContract` and updating via `PlaybackStateObserver`.
- **Handoff UX**: Integrate a native file picker converting selected media via `LocalPlaybackSourceHandoff` to open in the playback controller.
- **Video Surface integration**: Integrate the video rendering surface widget bound to the player runtime adapter.

## Capabilities

### New Capabilities
- `desktop-app-shell`: Represents the desktop app scaffolding, theme tokens, composition root, and global navigation rail.
- `desktop-playback-ui`: Represents the production playback screen with the video surface, file-picker handoff, and capability-driven control overlay.

### Modified Capabilities
<!-- No requirement changes to existing core specs, as the frontend strictly implements existing contracts. -->
