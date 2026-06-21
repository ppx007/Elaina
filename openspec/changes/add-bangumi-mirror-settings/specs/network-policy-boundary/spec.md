## ADDED Requirements

### Requirement: Bangumi mirror traffic SHALL remain provider governed
Bangumi mirror routing SHALL remain app-managed provider traffic governed by
ProviderGateway and SHALL NOT claim system-wide proxy, DNS, or VPN behavior.

#### Scenario: Mirror API request is prepared
- **WHEN** a Bangumi request uses the configured mirror API URL
- **THEN** ProviderGateway evaluates network policy against that effective
  request URL before dispatch

#### Scenario: Image mirror rewrites a Bangumi image
- **WHEN** a Bangumi image URL is rewritten to the configured image mirror URL
- **THEN** only Bangumi image hosts are rewritten and non-Bangumi image URLs are
  preserved
