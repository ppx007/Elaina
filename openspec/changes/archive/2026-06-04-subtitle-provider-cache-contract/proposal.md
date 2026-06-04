## Why

SubtitleProvider search and retrieval contracts already exist, but provider results have no persistent cache and no Domain-level orchestration that joins provider search, retrieval, cache policy, and parser handoff. Step 15 needs this contract slice before moving to RSS Engine work.

## What Changes

- Add a subtitle cache contract for provider search results and retrieved subtitle content with TTL semantics.
- Add a Domain subtitle discovery contract that coordinates local subtitle scanning, provider search, retrieval, and parser handoff.
- Preserve ProviderGateway routing for all provider-facing subtitle work.
- Extend subtitle provider and basic subtitle specs with cache, orchestration, and encoding-handoff requirements.
- Keep concrete OpenSubtitles HTTP, UI subtitle rendering, native track extraction, and network transport implementation out of scope.

## Capabilities

### New Capabilities

- `subtitle-provider-cache-contract`: subtitle search/content cache contracts and Domain subtitle discovery orchestration for provider-backed subtitles.

### Modified Capabilities

- `subtitle-provider-boundary`: adds cache and Domain orchestration requirements for provider-backed subtitle search and retrieval.
- `basic-subtitle-core`: adds parser handoff and encoding propagation requirements for retrieved provider subtitles.
- `local-storage-foundation`: adds subtitle cache as a first-class Storage responsibility.

## Impact

Affected code includes subtitle provider contracts, Domain subtitle bridge/orchestration contracts, Storage foundation contracts, subtitle parser handoff surfaces, and contract tests/checker validation. No UI, concrete network client, or native playback adapter changes are part of this proposal.
