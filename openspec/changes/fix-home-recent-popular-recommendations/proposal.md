## Why

The home page recommendation feed was using Bangumi's historical rank sorting
and rendering ranking-oriented copy. That makes the "popular" area behave like
an all-time chart instead of a recent hot recommendation surface.

## What Changes

- Request Bangumi popular anime using recent heat sorting instead of rank
  sorting, with the home hero fed by seven hot subjects.
- Keep the UI recommendation copy focused on recent popularity and heat, not
  historical ranking.
- Replace the former mid-page recent-hot carousel with a Bangumi recent watching
  section that requires an authenticated tracking snapshot.
- Render the "more recommendations" area as a waterfall layout.
- Add tests that prevent `rank` from reappearing as the home recommendation
  ordering or display signal and cover the recent watching states.

## Impact

- Affects Bangumi provider discovery requests.
- Affects the home page recommendation labels and metadata sentence.
- Affects the home page consumption of tracking snapshots for recent watching.
- Does not change playback, login, or local media flows.
