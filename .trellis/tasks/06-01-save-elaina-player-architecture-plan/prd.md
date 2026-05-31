# Save Celesteria Player Architecture Plan

## Goal

Save the finalized architecture rollout plan for the ACG player project into the project folder as a durable project document. The software name is `Celesteria`, abbreviated as `1017`.

## Requirements

* Create a project documentation folder if one does not already exist.
* Save the v20.4 staged architecture plan as a Markdown document under `docs/`.
* Include the updated RSS-based yuc.wiki seasonal anime flow.
* Preserve extension points for players, providers, RSS consumers, storage, network policy, enhancement profiles, and diagnostics.
* Record UX constraints that prevent feature confusion, especially on the video detail page and playback page.

## Acceptance Criteria

* [x] The plan exists in the project folder under `docs/`.
* [x] The plan names the software as `Celesteria` and records the abbreviation `1017`.
* [x] The plan includes 30 staged steps.
* [x] The plan treats yuc.wiki as an RSS `FeedSource`, not as a hardcoded page scraping provider.
* [x] The plan documents extension points and non-hardcoded module boundaries.

## Definition of Done

* Documentation file is added.
* Trellis task PRD records the scope.
* No application code is changed.

## Out of Scope

* Implementing the player.
* Creating app scaffolding.
* Integrating MPV, Bangumi, Dandanplay, libtorrent, or yuc.wiki.
* Choosing final product branding beyond the current project codename.

## Technical Notes

* Project docs are stored in `docs/celesteria-architecture-plan.md`.
* The repository previously had no `docs/` directory.
