## ADDED Requirements

### Requirement: Player core bootstrap SHALL accept neutral runtime composition descriptors
The player core bootstrap SHALL accept a neutral composition descriptor that
pairs a player binding with its verified capability matrix, so external app
composition roots can wire concrete playback without Domain runtime files
importing concrete media_kit/libmpv implementation code.

#### Scenario: Composition descriptor is supplied
- **WHEN** the app composition root supplies a player runtime composition
  descriptor
- **THEN** `PlayerCoreBootstrap` constructs a bound `PlayerCoreRuntime` using
  the descriptor binding and capability matrix while preserving the existing
  unsupported and deterministic bootstrap paths

#### Scenario: Concrete player backend is unavailable
- **WHEN** the composition descriptor's concrete binding fails to initialize or
  execute a command
- **THEN** player-core runtime returns the binding's normalized playback failure
  instead of leaking concrete backend exceptions
