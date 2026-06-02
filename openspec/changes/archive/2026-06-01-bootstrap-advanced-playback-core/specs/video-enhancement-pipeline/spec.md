## ADDED Requirements

### Requirement: Video enhancement pipeline SHALL define declarative profiles
The system SHALL define video enhancement profiles for scaler, HDR, deband, and Anime4K-style preset intent without exposing concrete MPV shader or renderer implementation details to UI.

#### Scenario: Enhancement profile is selected
- **WHEN** a user or profile selects an enhancement mode
- **THEN** the selected intent is represented by a declarative profile that an adapter can accept, reject, or degrade

### Requirement: Enhancement pipeline SHALL remain capability gated
The system SHALL require adapters to declare which enhancement features are supported before UI presents them as available actions.

#### Scenario: Adapter lacks Anime4K support
- **WHEN** the active adapter cannot support an Anime4K-style preset
- **THEN** the capability matrix hides or disables that enhancement option

### Requirement: Enhancement pipeline SHALL expose render budget inputs
The system SHALL define render budget inputs that can be consumed by sync/degradation contracts without turning the enhancement pipeline into diagnostics center behavior.

#### Scenario: Enhancement costs exceed budget
- **WHEN** enhancement rendering exceeds the available frame budget
- **THEN** sync/degradation contracts can request a lower profile or disabled enhancement state
