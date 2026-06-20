## Context

The core contracts, playback controllers, and background services for Elaina (1017) are successfully implemented through Phase 6 (Step 60). However, the app lacks a desktop entry point, layout rail, central styling theme, and a local media file playback screen. This document outlines the technical design for these frontend foundation modules.

## Goals / Non-Goals

**Goals:**
- Provide a runnable desktop entry point (`lib/main.dart`) on Windows.
- Define a centralized theme system to enforce the "no magic values" constraint.
- Build a responsive layout shell with a navigation sidebar representing all core pages.
- Establish a single-owner composition root managing the player runtime lifecycle.
- Deliver local media playback via the native file picker and playback handoff contract.

**Non-Goals:**
- Implementing production databases, download scheduling, RSS scraping, or diagnostics parsing in this change.
- Styling other screens beyond the App Shell and Playback screen (other pages will render simple placeholder scaffolds).
- Implementing advanced danmaku rendering or custom video enhancement pipelines in this change.

## Decisions

### 1. Centralized Theme System (No Magic Values)
- **Choice**: Create `lib/src/ui/theme/elaina_theme.dart` exporting a dedicated color, spacing, and typography schema.
- **Rationale**: To prevent magic numbers/colors scattered in widget classes, all widgets will reference static constants like `ElainaColors.background` and `ElainaSpacing.medium`.

### 2. Dependency Injection & Runtime Composition Root
- **Choice**: The `App` widget at `lib/main.dart` acts as the composition root, creating the player composition once at startup and passing it down using Flutter's `InheritedWidget` or vanilla dependency injection.
- **Rationale**: Ensures runtime player adaptors are instantiated exactly once and cleanly disposed of when the app is shut down.

### 3. Interface-gated Playback Page
- **Choice**: Retain and extend the `FlutterPlaybackShellDriver` abstraction.
- **Rationale**: Keeps widgets testable in headless testing environments (without initializing the native libmpv engine) while allowing controller-driven bindings in the production environment.

## Risks / Trade-offs

- **[Risk] Missing libmpv-2.dll on Developer Machine** → **Mitigation**: The app shell and playback UI will gracefully handle controller failures and display a clear warning/instructions panel if the native library fails to load, allowing development to proceed with the mock driver.
