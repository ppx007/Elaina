## ADDED Requirements

### Requirement: Capability matrix SHALL drive executable controller surface state
The active playback capability matrix SHALL determine every visible playback control and secondary panel returned by the Domain playback controller surface state.

#### Scenario: Only transport controls are supported
- **WHEN** the active adapter supports play/pause, seek, stop, and progress reporting but not track switching or secondary panels
- **THEN** the controller surface state exposes transport and progress controls only

#### Scenario: Track capabilities are supported
- **WHEN** the active adapter supports audio track switching, subtitle track switching, and secondary panels
- **THEN** the controller surface state exposes audio track controls, subtitle track controls, and the tracks panel entry point

### Requirement: Unsupported capabilities SHALL remain explicit in runtime checks
The runtime slice SHALL preserve explicit unsupported statuses and reasons for capabilities that are not declared by the active adapter.

#### Scenario: Capability is missing from adapter declaration
- **WHEN** runtime code asks for a capability that the active adapter did not declare
- **THEN** the capability matrix reports it as unsupported with a reason instead of treating it as supported by default
