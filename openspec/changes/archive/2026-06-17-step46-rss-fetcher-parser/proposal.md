## Why

Step 45 closed the local media-library flow. The next Phase D slice is Step 46:
real RSS/Atom fetching and parsing. Current RSS runtime contracts can register
sources, refresh through `FeedFetcher`, parse through `FeedParser`, dedupe, and
persist accepted items, but the repository still only has deterministic fake
fetchers and parsers.

This change adds the first concrete, non-UI feed integration path while keeping
RSS source management, UI pages, auto-download, seasonal indexing, BT, online
rules, diagnostics, and network policy implementations outside the slice.

## What Changes

- Add a Provider-layer HTTP feed fetcher implementation:
  - `dart:io` transport stays in `lib/src/provider/rss/**`.
  - conditional fetch validators use ETag and Last-Modified headers.
  - HTTP failures normalize through `ProviderFailure` /
    `AcgProviderFailureKind`.
  - gateway execution is preserved before transport access.
- Add RSS and Atom XML feed parsers:
  - parse source-neutral `FeedItem` values;
  - derive stable dedupe keys from GUID/id/link values with title fallback;
  - surface parser warnings and typed malformed-feed failures.
- Update RSS engine handling for concrete-parser behavior:
  - not-modified fetch responses return a successful empty refresh without
    parser invocation;
  - parser `ProviderFailure` exceptions become typed refresh failures.
- Add focused tests, non-UI smoke tooling, checker coverage, and integration
  notes.

## Impact

- Affected code is limited to provider RSS implementation, RSS contracts/runtime
  compatibility, tests, tools/checkers, docs, public exports, and OpenSpec
  specs.
- `lib/src/ui/**`, `lib/main.dart`, `windows/**`, BT, seasonal indexing,
  RSS auto-download, online rules, diagnostics, and native player code remain
  untouched.
