# Redesign Local Media Library Page

## Summary
Redesign the local media library page into a professional desktop management
workspace for configured folders, indexed media, local playback progress,
Bangumi bindings, and detail navigation. The page must continue to consume the
existing `MediaLibraryRuntime` boundary instead of introducing UI-owned scanner,
storage, provider, or playback shortcuts.

## Motivation
The current media library page mixes folder settings, scanning, catalog cards,
matching, and playback in one vertical surface. It lacks search, filters,
selection details, summary metrics, and clear failure states. It also performs
single-file playback preparation in UI code, which duplicates the runtime
handoff boundary.
