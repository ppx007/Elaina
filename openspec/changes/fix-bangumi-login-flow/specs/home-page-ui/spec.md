## ADDED Requirements

### Requirement: Home page SHALL show public Bangumi popular anime while signed out
The home page SHALL render public Bangumi popular anime recommendations without
requiring a signed-in Bangumi account, user collection data, or local media
bindings.

#### Scenario: Signed-out user opens the home page
- **WHEN** no Bangumi profile session is available
- **THEN** the home page requests public anime rankings through a Domain/provider
  recommendation contract
- **AND** popular recommendation cards include a concise Bangumi ranking
  sentence such as rank, score, and collection count when those fields are
  available
- **AND** UI code does not call Bangumi HTTP endpoints directly
