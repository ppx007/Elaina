# Add Home Bangumi Search

## Summary
Add a home-page Bangumi search entry that opens a full-screen typeahead search
surface. Search remains a provider-backed enrichment, available without login,
and result selection opens the existing video detail overlay.

## Motivation
Users need a direct way to find Bangumi subjects from the home page without
digging through recommendations. The implementation must preserve the provider
boundary and avoid UI-side HTTP or Bangumi JSON handling.
