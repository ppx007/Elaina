## 1. OpenSpec

- [x] 1.1 Create change `integrate-bangumi-api-matching`.
- [x] 1.2 Add proposal and spec deltas for Bangumi API matching.
- [x] 1.3 Run `openspec.cmd instructions apply --change "integrate-bangumi-api-matching" --json`.

## 2. Bangumi API Boundary

- [x] 2.1 Replace the generic Bangumi API User-Agent with a compliant Elaina
  User-Agent containing owner, app, version, platform, and project URL.
- [x] 2.2 Document that Bangumi garage components are not a desktop
  integration surface.
- [x] 2.3 Keep OAuth application secrets out of source and preserve optional
  token-based auth.

## 3. Local Media Matching

- [x] 3.1 Add a Domain-level local media Bangumi match service that uses
  `BangumiProvider.searchSubjects` instead of UI/provider direct HTTP calls.
- [x] 3.2 Normalize local media filenames into bounded search queries without
  overfitting to one fansub naming style.
- [x] 3.3 Save confirmed matches through `ProviderBindingStore` as
  `userConfirmed` Bangumi bindings.

## 4. UI Integration

- [x] 4.1 Add a media-library action for searching Bangumi candidates for a
  local item.
- [x] 4.2 Show candidate choices and require user confirmation before binding.
- [x] 4.3 Preserve tracking page semantics so only user-confirmed bindings
  appear in Bangumi tracking.

## 5. Validation

- [x] 5.1 Add focused provider/domain/UI tests for User-Agent and matching flow.
- [x] 5.2 Run `openspec.cmd validate "integrate-bangumi-api-matching" --strict`.
- [x] 5.3 Run Dart/Flutter analysis and focused tests.
