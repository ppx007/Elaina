## Why

Bangumi login is currently a settings shortcut instead of an authentication
flow. The tracking page login button only opens the settings page, and the
manual access-token field stores text through a delayed callback without
validating that the token can actually load the current Bangumi session.

This leaves the user with two broken paths: clicking login does not open the
Bangumi authorization page, and pasting a token does not give a clear,
immediate signed-in state.

## What Changes

- Add a small Domain-level Bangumi login controller so UI actions do not import
  concrete Bangumi HTTP client or transport details.
- Start Bangumi login by opening the Bangumi OAuth authorization page in the
  system browser. Server-side OAuth callback/token exchange remains out of
  scope until a callback service is intentionally deployed, so manual access
  token paste remains available in settings.
- Validate manually entered access tokens by saving them, requesting the
  current Bangumi session through the existing auth provider, and refreshing
  the shared profile projection only after the auth state changes.
- Load the authenticated user's Bangumi anime collection through the provider
  runtime and refresh the tracking page after auth state changes.
- Open remote Bangumi tracking entries into a real detail page by loading
  subject metadata, cover art, and episode lists through the provider runtime.
- Keep App Secret, user access tokens, and refresh tokens out of source.

## Impact

- Affects app composition, Bangumi provider URI helpers, settings UI, app shell
  login/tracking actions, profile/login/tracking domain contracts, and focused
  widget/provider tests.
- Does not make Bangumi login a prerequisite for playback, local media
  library, RSS, downloads, or provider matching.
- Does not add browser automation, cookie scraping, or Bangumi component-script
  loading.
