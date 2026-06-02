## 1. MPV adapter boundary

- [x] 1.1 Define `PlayerAdapter` source contracts for local file, HTTP, and HLS playback in the Playback layer.
- [x] 1.2 Scaffold an MPV adapter facade that either calls the selected native binding behind `PlayerAdapter` or explicitly reports local file, HTTP, and HLS playback as unsupported when no binding is available.
- [x] 1.3 Define adapter lifecycle and failure semantics for load, play, pause, seek, stop, and dispose.

## 2. Capability matrix

- [x] 2.1 Define the playback capability matrix model for adapter and platform capabilities, including explicit unsupported states for MPV facade capabilities that are not backed by a concrete binding.
- [x] 2.2 Wire active adapter capability reporting into the Domain/Playback boundary.
- [x] 2.3 Ensure unsupported controls and panels can be hidden or disabled by capability lookup.

## 3. Playback page foundation

- [x] 3.1 Create the playback page foundation with video surface, basic controls, progress model, and secondary panel entry points.
- [x] 3.2 Ensure playback UI depends on Domain/Playback abstractions, not concrete MPV/VLC/native implementations.
- [x] 3.3 Keep provider metadata, danmaku, advanced subtitles, BT streaming, enhancement, and diagnostics out of this slice.

## 4. Track management

- [x] 4.1 Define normalized audio and subtitle track descriptors.
- [x] 4.2 Define track discovery and switching contracts through the Playback layer.
- [x] 4.3 Define unsupported-state behavior for adapters that cannot expose or switch a track type.

## 5. Verification and next boundary

- [x] 5.1 Verify Phase 1 / Step 5-8 does not regress Phase 0 layer, gateway, storage, or invalidation constraints.
- [x] 5.2 Verify UI has no direct imports of MPV, VLC, media-kit, libmpv, ExoPlayer, AVPlayer, or platform-native player bindings.
- [x] 5.3 Prepare the next change boundary for Phase 2 / Step 9-12 only after player-core contracts are stable.
