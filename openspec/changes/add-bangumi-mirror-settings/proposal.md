# Add Bangumi Mirror Settings

## Summary
Add an optional user-configured Bangumi mirror path for API and image traffic.
Elaina defaults to official Bangumi endpoints, but users can deploy a
Cloudflare Worker mirror and enable it from Settings.

## Motivation
Bangumi API and image access can be unreliable from some networks. The app
should support a self-hosted mirror without embedding a public third-party
mirror or bypassing ProviderGateway governance.
