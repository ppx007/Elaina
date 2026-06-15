## MODIFIED Requirements

### Requirement: Repository baseline SHALL record Step 26 RSS auto-download policy runtime boundary
The repository baseline SHALL record that Step 26 adds the RSS auto-download policy runtime acceptance layer (bootstrap, scoped projections, typed outcomes, restart replay, dispose/unavailable/capability gates) and that concrete torrent engines, libtorrent bindings, FeedFetcher/FeedParser duplication, online source rule runtimes, WebView challenge handling, captcha solving, DNS/network policy, diagnostics center actions, mandatory automation startup, yuc.wiki special-casing, and Flutter rendering remain outside the Step 26 slice boundary.

#### Scenario: Step 26 runtime boundary is documented
- **WHEN** future changes reference which capabilities Step 26 introduced
- **THEN** the repository baseline records that Step 26 added RssAutoDownloadPolicyRuntimeBootstrap, RssAutoDownloadPolicyRuntime, typed outcome types, projection types, and restart replay without introducing concrete torrent engine, duplicate RSS engine, mandatory automation, or UI dependencies

#### Scenario: Step 26 runtime boundary validation is enforced
- **WHEN** Step 26 runtime, test, and checker files are validated against boundary constraints
- **THEN** no FeedFetcher, FeedParser, libtorrent, WebView, captcha, DNS, proxy, diagnostics, online rule runtime, or Flutter dependency is present in the runtime slice
