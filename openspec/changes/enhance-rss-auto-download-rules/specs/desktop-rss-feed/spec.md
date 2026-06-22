## MODIFIED Requirements

### Requirement: RSS Page SHALL manage auto download policy
The RSS page SHALL allow users to toggle auto-download activation and manage
feed-scoped auto-download rules through the RSS runtime boundary.

#### Scenario: Enable auto download on feed
- **WHEN** the user enables the auto-download toggle for a selected feed
- **THEN** the UI updates the feed activation through `RssEngineRuntime`
- **AND** the current activation state is reflected in the source list
- **AND** no item is automatically downloaded unless at least one enabled rule
  for that feed accepts the item

#### Scenario: Manage feed-scoped rules
- **WHEN** the user creates, edits, disables, or deletes an auto-download rule
- **THEN** the UI persists the rule through `RssEngineRuntime`
- **AND** the rule is scoped to the selected feed
- **AND** the UI does not access storage contracts, policy evaluator internals,
  concrete torrent engines, or concrete HTTP clients

#### Scenario: Preview rule matches
- **WHEN** the user previews a rule against currently accepted feed items
- **THEN** the page displays matched, rejected, and duplicate counts from the
  runtime preview result
- **AND** the preview uses the same RSS policy rule semantics as execution

#### Scenario: Filter auto-download matches
- **WHEN** the user selects the auto-download match item filter
- **THEN** the item stream shows only items accepted by enabled rules for their
  feed scope without fetching network data directly from the UI
