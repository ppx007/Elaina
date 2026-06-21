## 1. Provider Semantics

- [x] 1.1 Change the concrete Bangumi popular anime request to use heat sorting
  instead of rank sorting.
- [x] 1.2 Adjust deterministic Bangumi discovery ordering so it no longer uses
  historical rank as the primary recommendation signal.

## 2. UI Semantics

- [x] 2.1 Change home recommendation labels from rank/ranking to recent
  popularity and heat.
- [x] 2.2 Stop rendering historical Bangumi rank in the home recommendation
  metadata sentence.
- [x] 2.3 Limit the top home hero carousel to seven hot recommendation subjects.
- [x] 2.4 Replace the former recent-hot mid-page carousel with a recent watching
  section backed by Bangumi tracking data.
- [x] 2.5 Render more recommendations as a waterfall layout.

## 3. Validation

- [x] 3.1 Add provider tests for `sort=heat`.
- [x] 3.2 Add UI tests proving a ranked subject is rendered as recent popular
  content without ranking copy.
- [x] 3.3 Add UI coverage for signed-out and signed-in recent watching states.
