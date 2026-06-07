## 1. Storage and Manifest Records

- [x] 1.1 Add Storage-layer records for online rule source manifests, manifest versions, target rule sets, extraction operations, validation issues, evaluation snapshots, page retrieval outcomes, unsupported operations, and source capability state.
- [x] 1.2 Add an `OnlineRuleRuntimeStore` interface and deterministic in-memory store following existing Storage contract patterns.
- [x] 1.3 Expose online rule runtime persistence through `StorageDomain`, `StorageFoundation`, and public barrel exports.

## 2. Runtime Contracts and Normalized Outputs

- [x] 2.1 Extend online rule runtime contracts with typed registration, validation, refresh, retrieval, evaluation, unsupported-operation, disabled, and capability outcomes/failures.
- [x] 2.2 Add normalized read models for search results, detail metadata, episode entries, and playable-source candidates while keeping source-specific selector details inside the runtime boundary.
- [x] 2.3 Implement deterministic contract scaffolding for CSS selector, XPath 1.0 intent, and regex extraction over supplied documents without adding concrete crawler, scraper, JavaScript, WASM, or WebView behavior.

## 3. Gateway, Network, Invalidation, and Boundaries

- [x] 3.1 Add ProviderGateway-facing request/read models for manifest updates and page retrieval with provider identity, cache key, rate policy, retry policy, and normalized failure mapping.
- [x] 3.2 Add or refine network-policy handoff contracts so rule-source traffic carries provider-scoped SSRF/routing/capability failure context without implementing DNS, proxy, VPN, or resolver behavior.
- [x] 3.3 Add online rule invalidation events for manifest changes, validation changes, evaluation snapshots, page retrieval outcomes, unsupported operations, and source capability changes.
- [x] 3.4 Update Phase 6 checker rules and documentation to enforce Step 27 boundaries: no concrete crawler/scraper, no JS/WASM/scriptlets, no WebView challenge flow, no automatic captcha solving, no yuc.wiki special case, no diagnostics actions, and no mandatory online-rule startup.

## 4. Verification

- [x] 4.1 Add focused tests for manifest storage, typed validation outcomes, unsupported-operation rejection, normalized target read models, disabled runtime behavior, gateway/network handoff records, and invalidation publication.
- [x] 4.2 Update runtime validation to exercise the online rule runtime contract and guard against forbidden dependencies.
- [x] 4.3 Run `openspec validate "online-rule-runtime-contract" --strict`, `openspec validate --all`, `dart analyze`, focused tests, runtime checks, and Phase 6 checker scripts.
