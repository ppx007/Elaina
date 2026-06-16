## 1. OpenSpec

- [x] 1.1 Create change `step38-opensubtitles-api-client`.
- [x] 1.2 Add spec deltas for the concrete OpenSubtitles provider boundary.
- [x] 1.3 Run `openspec.cmd instructions apply --change "step38-opensubtitles-api-client" --json`.

## 2. Concrete Provider

- [x] 2.1 Add a Provider-layer OpenSubtitles API client with injectable transport.
- [x] 2.2 Map search responses into existing `SubtitleProviderCandidate` values.
- [x] 2.3 Map download-link responses and subtitle file retrieval into `RetrievedSubtitleFile`.
- [x] 2.4 Keep configuration minimal and name all provider constants.

## 3. Tests And Checkers

- [x] 3.1 Add fake-transport tests for request paths, headers, JSON mapping, and normalized failures.
- [x] 3.2 Extend subtitle runtime checks to require the concrete provider and forbid boundary leaks.
- [x] 3.3 Confirm UI, app shell, Windows runner, playback runtime, streaming, storage implementation, and network runtime files remain outside the change.

## 4. Validation And Archive

- [x] 4.1 Run focused subtitle-provider tests and checkers.
- [x] 4.2 Run `openspec.cmd validate "step38-opensubtitles-api-client" --strict`.
- [x] 4.3 Run baseline validation gates.
- [x] 4.4 Archive the OpenSpec change.
- [x] 4.5 Re-run `openspec.cmd validate --all` and report git status.
