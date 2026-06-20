## 1. Setup and Theme Scaffolding

- [x] 1.1 Run `flutter create --platforms=windows .` to scaffold the Windows desktop runner [UI Layer]
- [x] 1.2 Create `lib/src/ui/theme/elaina_theme.dart` with color (dark glassmorphic), spacing, and font constants, ensuring no magic values [UI Layer]
- [x] 1.3 Create `lib/main.dart` app entry point with single-owner composition root for player runtime lifecycle management [UI Layer]

## 2. Navigation Shell and Page Routing

- [x] 2.1 Implement `ElainaAppShell` widget rendering a responsive sidebar navigation rail for all core pages [UI Layer]
- [x] 2.2 Implement placeholder screen widgets for Home, Media Library, Downloads, RSS, Settings, and Diagnostics [UI Layer]

## 3. Playback Screen and Local File Handoff

- [x] 3.1 Implement File Picker action that parses selected file paths through `LocalPlaybackSourceHandoff` [UI Layer]
- [x] 3.2 Implement `ProductionPlaybackPage` consuming `PlaybackPageContract` and rendering controls based on `PlaybackPageSurfaceDescriptor` [UI Layer]
- [x] 3.3 Integrate the player video rendering surface widget connected to the active adapter resolver [UI Layer]

## 4. Verification and Boundary Testing

- [x] 4.1 Update or write UI tests under `test/ui/playback/` ensuring contract compliance [UI Layer]
- [x] 4.2 Run repository analysis and layer boundary checks to ensure no forbidden concrete imports are present [UI Layer]
