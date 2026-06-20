## Context
The UI needs to be updated to match the final `nighttime_home.html` reference, establishing a premium, glassmorphic, cyber-themed interface. This involves updating `ElainaAppShell` and its nested pages.

## Goals / Non-Goals

**Goals:**
- Faithfully implement the layout, glassmorphism, and neon aesthetic of the HTML reference.
- Add dynamic auto-scrolling carousels for the Hero section and "Hot Updates".
- Implement the background particle effect using Flutter primitives without heavy external packages.

**Non-Goals:**
- Backend integration (the UI will use domain contracts; actual data binding is out of scope for this UI redesign).
- Overhauling the Video Detail or Settings pages (this change is strictly scoped to the Home page and App Shell).

## Decisions

- **Particle Background**: Will be implemented using a `CustomPainter` coupled with a `Ticker` (via `SingleTickerProviderStateMixin`) to handle the particle simulation natively, giving us control over frame rate and resources.
- **Carousels**: To achieve the auto-sliding effect, we will use a `ListView.builder` with a `ScrollController` attached to a `Timer.periodic`, rather than introducing a heavy carousel package. 
- **Glassmorphism Performance**: `BackdropFilter` will be used to achieve the frosted glass effect. Since this runs on desktop (Windows), GPU performance is typically sufficient, but we will ensure that `RepaintBoundary` is used to prevent the animated background from causing the entire UI tree to repaint.

## Risks / Trade-offs

- **Risk**: The particle animation could cause high CPU/GPU usage if not optimized.
  - **Mitigation**: Use `RepaintBoundary` around the `CustomPaint` widget. Limit the number of particles to a reasonable number (e.g., 50).
- **Risk**: `BackdropFilter` over a video surface might cause tearing or performance issues on lower-end hardware.
  - **Mitigation**: Ensure that the background effect is disabled or paused when fullscreen playback is active.
