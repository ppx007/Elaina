# Redesign Settings Page

## Summary
Redesign Settings into a global configuration center for real persisted options:
appearance, Bangumi, network policy, and local media library folders.

## Motivation
The previous Settings page mixed broken localized strings, raw preference keys,
implicit autosave, and options that were not consumed by runtime behavior. The
new page should expose only effective global configuration and keep business
objects such as RSS rules and download tasks in their own pages.
