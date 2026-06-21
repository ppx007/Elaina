## 1. Specs

- [x] 1.1 Create change `enhance-bangumi-video-detail`.
- [x] 1.2 Add Bangumi provider, video-detail runtime, and desktop detail UI
  spec deltas.

## 2. Provider And Domain Contracts

- [x] 2.1 Add Bangumi related-person, related-character, voice-actor, and
  related-subject domain/provider types.
- [x] 2.2 Add provider methods and deterministic request keys for subject
  persons, characters, and relations.
- [x] 2.3 Implement concrete API URI helpers, JSON mapping, gateway routing,
  cache policy, proxy propagation, and normalized failure behavior.

## 3. Detail Runtime

- [x] 3.1 Extend `VideoDetailViewData` with stats, credits, characters, and
  relations.
- [x] 3.2 Aggregate Bangumi optional detail tables through provider contracts
  while preserving subject failure semantics.
- [x] 3.3 Preserve local media, playback, tracking, conflict resolution, and
  local fallback behavior.

## 4. UI

- [x] 4.1 Redesign detail layout around poster, metrics, operations, summary,
  episodes, staff, characters/CV, and related subjects.
- [x] 4.2 Replace mojibake Chinese copy with valid UTF-8 text.
- [x] 4.3 Keep desktop/mobile responsive layout and clickable cursor behavior.

## 5. Validation

- [x] 5.1 Add provider tests for new endpoints, mapping, proxy/gateway routing,
  and failure normalization.
- [x] 5.2 Add detail runtime tests for complete metadata and optional table
  failure isolation.
- [x] 5.3 Add UI tests for staff, character/CV, metrics, and existing actions.
- [x] 5.4 Run Dart analysis, focused Flutter tests, OpenSpec validation, and
  changed-test Module gate.
