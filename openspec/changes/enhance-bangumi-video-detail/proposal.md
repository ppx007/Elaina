## Why

The current video detail page is still a thin playback/follow surface. It loads
Bangumi subject, episode, local playback, and tracking state, but it does not
surface core Bangumi detail data such as staff, character/cast rows, related
subjects, rating, rank, and collection totals. Several visible Chinese strings
in the detail UI are also mojibake, which makes the page look unfinished even
when the data is present.

## What Changes

- Extend the Bangumi provider contract with subject persons, subject
  characters, and subject relations, implemented by the concrete API provider
  through ProviderGateway-governed requests.
- Extend `VideoDetailViewData` with normalized Bangumi-derived metadata tables
  so UI continues to render only Domain data.
- Aggregate optional Bangumi detail tables in the video-detail runtime without
  making a single optional table failure break the main detail page.
- Redesign the detail page into a professional anime detail surface with
  poster, metrics, tracking operations, episode playback, staff, character/CV,
  and related-subject sections.
- Replace broken detail-page Chinese text with valid UTF-8 copy.

## Impact

- Affects Bangumi provider contracts/runtime, concrete Bangumi API mapping,
  video-detail domain/runtime/storage adapters, detail UI, focused tests, and
  OpenSpec deltas.
- Does not add Bangumi HTML scraping or a deployed OAuth callback service.
- Does not make Bangumi login required for public detail metadata, local
  playback, local media library, RSS, downloads, or provider matching.
