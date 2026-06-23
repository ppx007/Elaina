# Redesign Diagnostics Dashboard

## Summary
Redesign the Diagnostics page into an auto-refreshing local diagnostics dashboard with charted telemetry, event distribution, capability status, and a dense event table.

## Motivation
The previous page was a static two-tab console with broken Chinese text and manual refresh only. Diagnostics should be useful as a live read-only inspection surface while preserving the diagnostics boundary: no remote telemetry and no module control actions.
