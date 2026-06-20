## 1. Workflow

- [x] 1.1 Create change `fix-bangumi-login-flow`.
- [x] 1.2 Add proposal, task list, and spec deltas for Bangumi login behavior.

## 2. Login Boundary

- [x] 2.1 Add a Domain-level Bangumi login controller contract.
- [x] 2.2 Add provider helpers for the Bangumi token acquisition URI without
  embedding secrets or deploying a callback flow.
- [x] 2.3 Compose the login controller from app composition using the existing
  settings store and Bangumi auth provider.

## 3. UI Flow

- [x] 3.1 Change tracking-page login actions to open the Bangumi token
  acquisition page instead of only navigating to settings.
- [x] 3.2 Change the settings access-token field to validate and refresh
  profile state immediately after token submission.
- [x] 3.3 Surface auth start/save failures without blocking non-Bangumi
  features.
- [x] 3.4 Load the authenticated Bangumi anime collection through the provider
  runtime and refresh the tracking page after token login or manual refresh.
- [x] 3.5 Open remote tracking entries into a Bangumi-backed detail page with
  subject metadata, cover art, and episode list data.
- [x] 3.6 Project remote tracking status into video detail state and keep the
  global detail overlay above playback while it is open.
- [x] 3.7 Show public Bangumi popular anime recommendations on the home page
  for signed-out users, including concise ranking sentences.

## 4. Validation

- [x] 4.1 Add focused tests for token-page URI construction, login dispatch,
  manual token profile refresh, authenticated tracking refresh, and remote
  tracking detail navigation.
- [x] 4.2 Run format, focused tests, Dart analysis, OpenSpec validation, and a
  credential leak scan.
- [x] 4.3 Add regressions for tracked detail status rendering and detail
  overlay interaction while playback is active.
- [x] 4.4 Add provider and widget regressions for public Bangumi ranking
  recommendations on the signed-out home page.
