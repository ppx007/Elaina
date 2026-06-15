## MODIFIED Requirements

### Requirement: Repository baseline SHALL record Step 27 online rule source runtime boundary
The repository baseline SHALL record that Step 27 adds the online rule source runtime acceptance layer (bootstrap, scoped projections, typed outcomes, restart replay, disable/reenable, dispose/unavailable/capability gates) and that gateway page retrieval, network client, WebView challenge handling, captcha solving, DNS/network policy, diagnostics center actions, Flutter rendering, yuc.wiki special-casing, libtorrent bindings, registerSource, and refreshManifest remain outside the Step 27 slice boundary.

#### Scenario: Step 27 runtime boundary is documented
- **WHEN** future changes reference which capabilities Step 27 introduced
- **THEN** the repository baseline records that Step 27 added OnlineRuleSourceRuntimeBootstrap, OnlineRuleSourceRuntime, typed outcome types, projection types, and restart replay without introducing gateway, network, WebView, captcha, DNS, proxy, diagnostics, or UI dependencies
