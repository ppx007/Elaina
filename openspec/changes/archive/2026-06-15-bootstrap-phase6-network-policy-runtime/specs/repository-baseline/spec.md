## ADDED Requirements

### Requirement: Repository baseline SHALL record Step 29 network policy runtime boundary
The repository baseline SHALL record that Step 29 adds a network policy runtime acceptance layer with bootstrap composition, typed outcomes, store-backed projections, restart replay, provider assignment gates, capability gates, and invalidation publication.

#### Scenario: Step 29 runtime boundary is documented
- **WHEN** future work references Phase 6 DNS/network policy behavior
- **THEN** the repository baseline identifies `NetworkPolicyRuntimeBootstrap`, `NetworkPolicyRuntime`, runtime action results, projections, and boundary checkers as the Step 29 scope

### Requirement: Repository baseline SHALL validate Step 29 concrete-networking exclusions
The repository baseline SHALL require validation that Step 29 runtime files reject concrete DNS clients, DoH clients, DoT clients, proxy clients, proxy servers, PAC parsers, VPN/TUN behavior, kernel filtering, DPI, packet capture, sockets, platform network plugins, Flutter UI, native, FFI, platform channels, diagnostics implementation, provider dispatch, RSS, BT, online-rule, WebView, captcha, libtorrent, MPV, VLC, media-kit, and yuc.wiki dependencies.

#### Scenario: Step 29 checker rejects networking leakage
- **WHEN** Step 29 validation scans runtime files
- **THEN** forbidden networking, transport, UI, diagnostics, provider-dispatch, native, and unrelated runtime terms fail validation before archive
