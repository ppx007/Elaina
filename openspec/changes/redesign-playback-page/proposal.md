# Redesign Playback Page

## Summary
Redesign the production playback page into a capability-driven player console
that consumes existing playback state, subtitle/danmaku overlays, track
discovery, buffering, failures, and capability status.

## Motivation
The current production page exposes only a black video surface with basic
transport controls while the playback/domain contracts already publish richer
state. This leaves subtitles, danmaku, track switching, failure details, and
advanced playback capability status invisible to users.
