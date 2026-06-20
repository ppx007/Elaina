## Why

The current app shell and home page UI are functional but rely on basic placeholders and lack the polished, dynamic visual design required for a premium ACG player. A redesign based on the provided nighttime glassmorphism reference is needed to establish the core visual language and user experience for the application.

## What Changes

- Overhaul `ElainaAppShell` and its home page content to match the provided `nighttime_home.html` reference design.
- Implement glassmorphic styling, neon accents, and smooth animations (e.g., fade-in, pulse-ambient) within the Flutter UI layer.
- Integrate the auto-sliding hero carousel and "Hot Updates" horizontal scroll areas.
- Build the particle background effect in Flutter using a CustomPainter or an appropriate package, ensuring it meets performance requirements.
- Extract any UI text strings or layout properties into appropriate UI-layer configurations, avoiding domain/foundation layer pollution.

## Capabilities

### New Capabilities
- `home-page-ui`: Defines the visual layout, components, and animations for the new home page shell.

### Modified Capabilities

- 

## Impact

- **Affected Code**: `lib/src/ui/playback/shell/elaina_app_shell.dart`, `lib/src/ui/theme/elaina_theme.dart`, and new UI component files.
- **Dependencies**: May require additional animation or particle system packages if not built from scratch with `CustomPainter`.
- **Architecture**: Strictly confined to the UI layer. No impact on Domain or Foundation contracts.
