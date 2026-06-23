# Expand Diagnostics Workbench

## Summary
Upgrade the diagnostics page from a compact telemetry dashboard into a read-only
application workbench. The page must expose playback, downloads, RSS, local
media library, provider/network settings, event logs, and system telemetry from
existing runtime projections.

## Motivation
The current diagnostics page charts only memory, AV drift, event counts, and
diagnostics capabilities. That is not enough to debug real user reports, while
the playback page already exposes richer source, buffer, caption, danmaku, and
capability details. Diagnostics should aggregate those existing read models
without becoming a control surface or bypassing runtime boundaries.
