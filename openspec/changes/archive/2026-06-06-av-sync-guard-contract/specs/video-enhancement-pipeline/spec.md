## ADDED Requirements

### Requirement: Video enhancement pipeline SHALL treat AVSyncGuard as policy owner
The video enhancement pipeline SHALL expose budget pressure and candidate degradation targets as input data while AVSyncGuard owns drift thresholds, health transitions, and ordered degradation policy.

#### Scenario: AVSyncGuard consumes enhancement pressure
- **WHEN** enhancement rendering exceeds frame budget and A/V drift crosses guard thresholds
- **THEN** AVSyncGuard can select a degradation action using the enhancement pressure data without the enhancement pipeline deciding sync policy
