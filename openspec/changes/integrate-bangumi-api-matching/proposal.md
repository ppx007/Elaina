## Why

Elaina now has a concrete Bangumi API client and a configurable local media
library, but local media scanning only imports files and projects existing
provider bindings. It does not provide a user-confirmed Bangumi matching flow
for scanned media, and the current API client User-Agent is too generic for
Bangumi's published API guidance.

Bangumi's developer platform also exposes "garage" components, but those are
site-local JavaScript/CSS enhancements and are not an appropriate integration
surface for a desktop player. Elaina should use the official API boundary,
avoid site-cookie or component-script flows, and keep remote writes behind
explicit user action.

## What Changes

- Document and enforce a Bangumi API integration policy for desktop use:
  official API endpoints, provider gateway routing, compliant User-Agent, and
  no component-script integration.
- Add provider/domain support for local media Bangumi match candidates using
  existing Bangumi provider search contracts.
- Keep automatic candidate discovery separate from user-confirmed tracking:
  scanned files may receive candidates, but "My Tracking" only includes
  user-confirmed Bangumi bindings.
- Add a media-library UI path for matching a local media item to a Bangumi
  subject and confirming the binding.
- Preserve optional auth/progress behavior and avoid committing app secrets or
  requiring login for playback or local media indexing.

## Impact

- Affects Bangumi provider constants/docs, media domain matching runtime,
  media-library UI, and focused tests.
- Does not embed the Bangumi App Secret in source, docs, tests, or public
  repository content.
- Does not use Bangumi garage components, web scraping, cookie access, or
  browser automation.
- Remote Bangumi collection/progress writes remain explicit authenticated
  operations outside scan/import.
