## 1. Video enhancement pipeline

- [x] 1.1 Define enhancement profile contracts for scaler, HDR, deband, and Anime4K-style preset intent.
- [x] 1.2 Define render budget input contracts consumed by sync/degradation decisions.
- [x] 1.3 Define adapter capability boundaries so UI never imports MPV shader or renderer implementation details.

## 2. AVSyncGuard

- [x] 2.1 Define A/V drift, dropped-frame, render-delay, and enhancement-pressure metric contracts.
- [x] 2.2 Define degradation decisions for drift over 120ms and target-state reporting for drift under 40ms.
- [x] 2.3 Define deterministic degradation policy ordering for enhancement reduction and advanced rendering disablement.

## 3. Advanced caption rendering

- [x] 3.1 Define Matrix4 danmaku, dual-subtitle, PGS, and ASS enhancement capability contracts.
- [x] 3.2 Define ordered dual-subtitle request contracts that preserve primary/secondary track semantics.
- [x] 3.3 Ensure advanced caption contracts do not mutate basic subtitle parser or danmaku event foundations.

## 4. VLC fallback adapter

- [x] 4.1 Define fallback adapter registration, failure classification, and adapter selection contracts.
- [x] 4.2 Define capability hiding after fallback so unsupported features surface with reason strings.
- [x] 4.3 Ensure VLC fallback remains optional and never becomes a mandatory core playback path.

## 5. Verification and next boundary

- [x] 5.1 Verify UI does not import MPV shader, Anime4K, VLC, AVSyncGuard internals, or advanced renderer implementations.
- [x] 5.2 Verify playback capability matrix exposes advanced playback and fallback capability gating.
- [x] 5.3 Verify diagnostics center, DNS/network policy, online source rules, RSS auto-download, and WebView challenge handling remain out of scope.
