## ADDED Requirements

### Requirement: Player core runtime SHALL wire track discovery through active adapter
The player core runtime SHALL expose audio and subtitle track discovery through normalized Playback-layer descriptors returned by the active adapter facade.

#### Scenario: Adapter reports runtime tracks
- **WHEN** the active adapter reports audio and subtitle tracks to player core runtime
- **THEN** runtime consumers receive normalized track descriptors without native engine objects or UI-local identifiers

### Requirement: Player core runtime SHALL gate track switching by capability matrix
The player core runtime SHALL route track switching through Playback-layer contracts and SHALL reject track operations that are unsupported by the runtime capability matrix.

#### Scenario: Subtitle switching is unsupported
- **WHEN** a caller requests subtitle track switching while the runtime capability matrix marks subtitle switching unsupported
- **THEN** the switch operation returns a normalized unsupported result without delegating to native playback, UI state, provider metadata, storage, streaming, or network systems
