## ADDED Requirements

### Requirement: Repository baseline SHALL record Step 24 advanced caption rendering runtime
The system SHALL include a Step 24 baseline entry documenting the advanced caption rendering runtime/bootstrap acceptance layer, its typed projection and action result contracts, and its scope-gate boundary.

#### Scenario: Step 24 runtime baseline entry exists
- **WHEN** the repository baseline spec is read
- **THEN** a Step 24 advanced caption rendering runtime entry is present with bootstrap, projection, restart, and boundary descriptions

### Requirement: Repository baseline SHALL enforce Step 24 runtime boundary
The system SHALL require Step 24 runtime code to import only cache invalidation bus, advanced caption storage contracts, advanced caption rendering, and capability matrix — rejecting imports of native, FFI, VLC, renderer bindings, Flutter UI, diagnostics, network, RSS, WebView, and online rule modules.

#### Scenario: Boundary validation rejects out-of-scope imports
- **WHEN** the Step 24 runtime import boundary is checked
- **THEN** no import of native, FFI, VLC, renderer bindings, Flutter UI, diagnostics, network, RSS, WebView, or online rule modules is found
