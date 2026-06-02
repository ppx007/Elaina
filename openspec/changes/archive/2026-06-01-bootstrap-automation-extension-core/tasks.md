## 1. RSS automation policy

- [x] 1.1 Define RSS auto-download policy contracts for feed-scoped and global rules across Provider, Storage, and Streaming boundaries.
- [x] 1.2 Define declarative matcher contracts for title, group, episode, season, resolution, size, category, include/exclude, regex, glob, AND, OR, and negation semantics.
- [x] 1.3 Define durable automation history contracts for accepted items, rejected items, dedupe keys, and enqueue outcomes.
- [x] 1.4 Define engine-neutral BT task handoff contracts so automation never calls torrent engine APIs directly.

## 2. Online rule runtime

- [x] 2.1 Define versioned online rule manifest contracts for source identity, update metadata, validation status, and extraction targets.
- [x] 2.2 Define CSS selector, XPath 1.0, and regex extraction contracts for search, detail, episode, and playable-source page types.
- [x] 2.3 Define unsupported-operation handling for JavaScript, WASM, scriptlets, arbitrary code execution, and non-declarative scraping behavior.
- [x] 2.4 Route manifest updates and page retrieval through ProviderGateway and network policy contracts.

## 3. WebView session backfill and network policy

- [x] 3.1 Define manual-only challenge detection and isolated WebView completion contracts.
- [x] 3.2 Define normalized same-origin session artifact contracts and provider session handoff behavior.
- [x] 3.3 Define provider-scoped network policy contracts for ordered domain matching, DNS/proxy/direct/block intent, fallback, and audit metadata.
- [x] 3.4 Define SSRF protection contracts for unsafe schemes, loopback, link-local, private ranges, unsafe redirects, and blocked hosts.
- [x] 3.5 Define platform capability reporting for WebView capture, DNS intent, proxy intent, and background network limitations.

## 4. Diagnostics center

- [x] 4.1 Define typed local diagnostics event registry contracts with category, severity, schema version, correlation identity, and structured payload metadata.
- [x] 4.2 Define structured snapshot contracts for playback, BT, provider, RSS, online rule, network policy, cache, storage, and A/V sync flows.
- [x] 4.3 Define diagnostics filtering, retention, redaction, and local export contracts.
- [x] 4.4 Verify diagnostics remains read-only and cannot mutate provider state, playback state, network policy, RSS automation, or BT tasks.

## 5. Documentation and verification

- [x] 5.1 Document Phase 6 automation extension boundaries and anti-scope constraints.
- [x] 5.2 Add checker coverage for FeedSource reuse, ProviderGateway routing, manual-only WebView challenge handling, SSRF policy, diagnostics redaction, and optional capability gating.
- [x] 5.3 Verify online automation remains optional and does not become a prerequisite for local playback, media-library use, manual BT tasks, or core playback startup.
- [x] 5.4 Run OpenSpec validation and confirm the change is ready for apply.
