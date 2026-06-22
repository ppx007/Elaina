## MODIFIED Requirements

### Requirement: RSS Page SHALL display feed catalog
The RSS page SHALL show a management workspace for subscribed RSS or Atom
feeds and parsed catalog items retrieved from `RssEngineRuntime`.

#### Scenario: Display subscribed feeds
- **WHEN** the RSS page is loaded
- **THEN** it displays active feed subscriptions retrieved from
  `RssEngineRuntime`
- **AND** displays persisted and newly accepted feed items
- **AND** exposes source format, refresh interval, last refresh state, item
  counts, cursor state, and latest refresh outcome for each source

#### Scenario: Filter parsed items
- **WHEN** the user selects a source or enters search text
- **THEN** the item stream is filtered without fetching network data directly
  from the UI

### Requirement: RSS Page SHALL manage auto download policy
The RSS page SHALL allow users to toggle auto-download activation for specific
feed subscriptions through the runtime policy boundary.

#### Scenario: Enable auto download on feed
- **WHEN** the user enables the auto-download toggle for a selected feed
- **THEN** the UI updates the feed activation through `RssEngineRuntime`
- **AND** the current activation state is reflected in the source list

## ADDED Requirements

### Requirement: RSS Page SHALL provide subscription operations
The RSS page SHALL provide add, refresh, and remove actions for RSS
subscriptions without importing concrete feed fetchers, parsers, torrent
engines, or provider transports.

#### Scenario: Add subscription
- **WHEN** the user enters a valid name, URL, format, and refresh interval
- **THEN** the UI registers the source through `RssEngineRuntime`
- **AND** refreshes the source registry projection

#### Scenario: Remove subscription
- **WHEN** the user confirms removing a feed source
- **THEN** the UI removes the source through `RssEngineRuntime`
- **AND** parsed items and source-specific UI state for that source disappear

#### Scenario: Refresh subscription
- **WHEN** the user refreshes one source or all sources
- **THEN** the UI invokes runtime refresh actions
- **AND** displays success, warning, or failure state from typed runtime
  outcomes instead of using raw exceptions or transport details
